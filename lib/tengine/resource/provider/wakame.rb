# -*- coding: utf-8 -*-
require 'tama'

class Tengine::Resource::Provider::Wakame < Tengine::Resource::Provider::Ec2

  field :connection_settings, :type => Hash

  PHYSICAL_SERVER_STATES = [:online, :offline].freeze

  VIRTUAL_SERVER_STATES = [
    :scheduling, :pending, :starting, :running,
    :failingover, :shuttingdown, :terminated].freeze

  def update_virtual_server_images
    connect do |conn|
      hashs = conn.describe_images.map do |hash|
        {
          :provided_id => hash.delete(:aws_id),
          :provided_description => hash.delete(:aws_description),
        }
      end
      update_virtual_server_images_by(hashs)
    end
  end

  # @param  [String]                                 name         Name template for created virtual servers
  # @param  [Tengine::Resource::VirtualServerImage]  image        virtual server image object
  # @param  [Tengine::Resource::VirtualServerType]   type         virtual server type object
  # @param  [Tengine::Resource::PhysicalServer]      physical     physical server object
  # @param  [String]                                 description  what this virtual server is
  # @param  [Numeric]                                count        number of vortial servers to boot
  # @return [Array<Tengine::Resource::VirtualServer>]
  def create_virtual_servers name, image, type, physical, description = "", count = 1
    return super(
      name,
      image,
      type,
      physical.provided_id,
      description,
      count,  # min
      count,  # max
      [],     # grouop id
      self.properties[:key_name],
      "",     # user data
      nil,    # kernel id
      nil     # ramdisk id
    )
  end

  def terminate_virtual_servers servers
    connect do |conn|
      conn.terminate_instances(servers.map {|i| i.provided_id }).map do |hash|
        serv = self.virtual_servers.where(:provided_id => hash[:aws_instance_id]).first
        serv.update_attributes(:status => "shutdown in progress") if serv # <- ?
        serv
      end
    end
  end

  def capacities
    server_type_ids = virtual_server_types.map(&:provided_id)
    server_type_to_cpu = virtual_server_types.inject({}) do |d, server_type|
      d[server_type.provided_id] = server_type.cpu_cores
      d
    end
    server_type_to_mem = virtual_server_types.inject({}) do |d, server_type|
      d[server_type.provided_id] = server_type.memory_size
      d
    end
    physical_servers.inject({}) do |result, physical_server|
      if physical_server.status == 'online'
        cpu_free = physical_server.cpu_cores - physical_server.guest_servers.map{|s| server_type_to_cpu[s.provided_type_id]}.sum
        mem_free = physical_server.memory_size - physical_server.guest_servers.map{|s| server_type_to_mem[s.provided_type_id]}.sum
        result[physical_server.provided_id] = server_type_ids.inject({}) do |dest, server_type_id|
          dest[server_type_id] = [
            cpu_free / server_type_to_cpu[server_type_id],
            mem_free / server_type_to_mem[server_type_id]
          ].min
          dest
        end
      else
        result[physical_server.provided_id] = server_type_ids.inject({}) do |dest, server_type_id|
          dest[server_type_id] = 0; dest
        end
      end
      result
    end
  end


  # 仮想サーバタイプの監視
  def virtual_server_type_watch
    log_prefix = "#{self.class.name}#virtual_server_type_watch (provider:#{self.name}):"

    # APIからの仮想サーバタイプ情報を取得
    instance_specs = describe_instance_specs_for_api
    Tengine.logger.debug "#{log_prefix} describe_instance_specs for api (wakame)"
    Tengine.logger.debug "#{log_prefix} #{instance_specs.inspect}"

    create_instance_specs = []
    update_instance_specs = []
    destroy_server_types = []

    # 仮想イメージタイプの取得
    old_server_types = self.virtual_server_types
    Tengine.logger.debug "#{log_prefix} virtual_server_types on provider (#{self.name})"
    Tengine.logger.debug "#{log_prefix} #{old_server_types.inspect}"

    old_server_types.each do |old_server_type|
      instance_spec = instance_specs.detect do |instance_spec|
        (instance_spec[:id] || instance_spec["id"]) == old_server_type.provided_id
      end

      if instance_spec
        # APIで取得したサーバタイプと一致するものがあれば更新対象
        Tengine.logger.debug "#{log_prefix} registed virtual_server_type % <update> (#{old_server_type.provided_id})"
        update_instance_specs << instance_spec
      else
        # APIで取得したサーバタイプと一致するものがなければ削除対象
        Tengine.logger.debug "#{log_prefix} removed virtual_server_type % <destroy> (#{old_server_type.provided_id})"
        destroy_server_types << old_server_type
      end
    end
    # APIで取得したサーバタイプがTengine上に存在しないものであれば登録対象
    create_instance_specs = instance_specs - update_instance_specs
    create_instance_specs.each do |spec|
      Tengine.logger.debug "#{log_prefix} new virtual_server_type % <create> (#{spec['id']})"
    end

    # 更新
    self.differential_update_virtual_server_type_hashs(update_instance_specs) unless update_instance_specs.empty?
    # 登録
    self.create_virtual_server_type_hashs(create_instance_specs) unless create_instance_specs.empty?
    # 削除
    destroy_server_types.each { |target| target.destroy }
  end

  # 物理サーバの監視
  def physical_server_watch
    log_prefix = "#{self.class.name}#physical_server_watch (provider:#{self.name}):"

    # APIからの物理サーバ情報を取得
    host_nodes = describe_host_nodes_for_api
    Tengine.logger.debug "#{log_prefix} describe_host_nodes for api (wakame)"
    Tengine.logger.debug "#{log_prefix} #{host_nodes.inspect}"

    create_host_nodes = []
    update_host_nodes = []
    destroy_servers = []

    # 物理サーバの取得
    old_servers = self.physical_servers
    Tengine.logger.debug "#{log_prefix} physical_server on provider (#{self.name})"
    Tengine.logger.debug "#{log_prefix} #{old_servers.inspect}"

    old_servers.each do |old_server|
      host_node = host_nodes.detect do |host_node|
        (host_node[:id] || host_node["id"]) == old_server.provided_id
      end

      if host_node
        Tengine.logger.debug "#{log_prefix} registed physical_server % <update> (#{old_server.provided_id})"
        update_host_nodes << host_node
      else
        Tengine.logger.debug "#{log_prefix} removed physical_server % <destroy> (#{old_server.provided_id})"
        destroy_servers << old_server
      end
    end
    create_host_nodes = host_nodes - update_host_nodes
    create_host_nodes.each do |host_node|
      Tengine.logger.debug "#{log_prefix} new physical_server% <create> (#{host_node['id']})"
    end

    self.differential_update_physical_server_hashs(update_host_nodes) unless update_host_nodes.empty?
    self.create_physical_server_hashs(create_host_nodes) unless create_host_nodes.empty?
    destroy_servers.each { |target| target.destroy }
  end

  # 仮想サーバの監視
  def virtual_server_watch
    log_prefix = "#{self.class.name}#virtual_server_watch (provider:#{self.name}):"

    # APIからの仮想サーバ情報を取得
    instances = describe_instances_for_api
    Tengine.logger.debug "#{log_prefix} describe_instances for api (wakame)"
    Tengine.logger.debug "#{log_prefix} #{instances.inspect}"

    create_instances = []
    update_instances = []
    destroy_servers = []

    # 仮想サーバの取得
    old_servers = self.virtual_servers
    Tengine.logger.debug "#{log_prefix} virtual_servers on provider (#{self.name})"
    Tengine.logger.debug "#{log_prefix} #{old_servers.inspect}"

    old_servers.each do |old_server|
      instance = instances.detect do |instance|
        (instance[:aws_instance_id] || instance["aws_instance_id"]) == old_server.provided_id
      end

      if instance
        Tengine.logger.debug "#{log_prefix} registed virtual_server % <update> (#{old_server.provided_id})"
        update_instances << instance
      else
        Tengine.logger.debug "#{log_prefix} removed virtual_server % <destroy> (#{old_server.provided_id})"
        destroy_servers << old_server
      end
    end
    create_instances = instances - update_instances
    create_instances.each do |instance|
      Tengine.logger.debug "#{log_prefix} new virtual_server % <create> (#{instance[:aws_instance_id]})"
    end

    self.differential_update_virtual_server_hashs(update_instances) unless update_instances.empty?
    self.create_virtual_server_hashs(create_instances) unless create_instances.empty?
    destroy_servers.each { |target| target.destroy }
  end

  # 仮想サーバイメージの監視
  def virtual_server_image_watch
    log_prefix = "#{self.class.name}#virtual_server_image_watch (provider:#{self.name}):"

    # APIからの仮想サーバイメージ情報を取得
    images = describe_images_for_api
    Tengine.logger.debug "#{log_prefix} describe_images for api (wakame)"
    Tengine.logger.debug "#{log_prefix} #{images.inspect}"

    create_images = []
    update_images = []
    destroy_server_images = []

    # 仮想サーバイメージの取得
    old_images = self.virtual_server_images
    Tengine.logger.debug "#{log_prefix} virtual_server_images on provider (#{self.name})"
    Tengine.logger.debug "#{log_prefix} #{old_images.inspect}"

    old_images.each do |old_image|
      image = images.detect do |image|
        (image[:aws_id] || image["aws_id"]) == old_image.provided_id
      end

      if image
        Tengine.logger.debug "#{log_prefix} registed virtualserver_image % <update> (#{old_image.provided_id})"
        update_images << image
      else
        Tengine.logger.debug "#{log_prefix} removed virtual_server_image % <destroy> (#{old_image.provided_id})"
        destroy_server_images << old_image
      end
    end
    create_images = images - update_images
    create_images.each do |image|
      Tengine.logger.debug "#{log_prefix} new server_image % <create> (#{image[:aws_id]})"
    end

    self.differential_update_virtual_server_image_hashs(update_images) unless update_images.empty?
    self.create_virtual_server_image_hashs(create_images) unless create_images.empty?
    destroy_server_images.each { |target| target.destroy }
  end

  # virtual_server_type
  def differential_update_virtual_server_type_hash(hash)
    properties = hash.dup
    properties.symbolize_keys!
    virtual_server_type = self.virtual_server_types.where(:provided_id => properties[:id]).first
    virtual_server_type.provided_id = properties.delete(:id)
    virtual_server_type.caption = properties.delete(:uuid)
    virtual_server_type.cpu_cores = properties.delete(:cpu_cores)
    virtual_server_type.memory_size = properties.delete(:memory_size)
    properties.each do |key, val|
      value =  properties.delete(key)
      unless val.to_s == value.to_s
        if virtual_server_type.properties[key.to_sym]
          virtual_server_type.properties[key.to_sym] = value
        else
          virtual_server_type.properties[key.to_s] = value
        end
      end
    end
    virtual_server_type.save! if virtual_server_type.changed?
  end

  def differential_update_virtual_server_type_hashs(hashs)
    updated_server_types = []
    hashs.each do |hash|
      server_type = differential_update_virtual_server_type_hash(hash)
      updated_server_types << server_type
    end
    updated_server_types
  end

  def create_virtual_server_type_hash(hash)
    properties = hash.dup
    properties.symbolize_keys!
    self.virtual_server_types.create!(
      :provided_id => properties.delete(:id),
      :caption => properties.delete(:uuid),
      :cpu_cores => properties.delete(:cpu_cores),
      :memory_size => properties.delete(:memory_size),
      :properties => properties)
  end

  def create_virtual_server_type_hashs(hashs)
    created_ids = []
    hashs.each do |hash|
      server_type = create_virtual_server_type_hash(hash)
      created_ids << server_type.id
    end
    created_ids
  end

  # physical_server
  def differential_update_physical_server_hash(hash)
    properties = hash.dup
    properties.symbolize_keys!
    physical_server = self.physical_servers.where(:provided_id => properties[:id]).first
    # wakame-adapters-tengine が name を返さない仕様の場合は、provided_id を name に登録します
    physical_server.name = properties.delete(:name) || properties[:id]
    physical_server.provided_id = properties.delete(:id)
    physical_server.status = properties.delete(:status)
    physical_server.cpu_cores = properties.delete(:offering_cpu_cores)
    physical_server.memory_size = properties.delete(:offering_memory_size)
    properties.each do |key, val|
      value =  properties.delete(key)
      unless val.to_s == value.to_s
        if physical_server.properties[key.to_sym]
          physical_server.properties[key.to_sym] = value
        else
          physical_server.properties[key.to_s] = value
        end
      end
    end
    physical_server.save! if physical_server.changed?
  end

  def differential_update_physical_server_hashs(hashs)
    updated_servers = []
    hashs.each do |hash|
      server = differential_update_physical_server_hash(hash)
      updated_servers << server
    end
    updated_servers
  end

  def create_physical_server_hash(hash)
    properties = hash.dup
    properties.symbolize_keys!
    self.physical_servers.create!(
      # wakame-adapters-tengine が name を返さない仕様の場合は、provided_id を name に登録します
      :name => properties.delete(:name) || properties[:id],
      :provided_id => properties.delete(:id),
      :status => properties.delete(:status),
      :cpu_cores => properties.delete(:offering_cpu_cores),
      :memory_size => properties.delete(:offering_memory_size),
      :properties => properties)
  end

  def create_physical_server_hashs(hashs)
    created_ids = []
    hashs.each do |hash|
      server = create_physical_server_hash(hash)
      created_ids << server.id
    end
    created_ids
  end

  # virtual_server_image
  def differential_update_virtual_server_image_hash(hash)
    properties = hash.dup
    properties.symbolize_keys!
    server_image = self.virtual_server_images.where(:provided_id => properties[:aws_id]).first
    server_image.provided_id = properties.delete(:aws_id)
    server_image.provided_description = properties.delete(:description)
    server_image.save! if server_image.changed?
  end

  def differential_update_virtual_server_image_hashs(hashs)
    updated_images = []
    hashs.each do |hash|
      image = differential_update_virtual_server_image_hash(hash)
      updated_images << image
    end
    updated_images
  end

  def create_virtual_server_image_hash(hash)
    properties = hash.dup
    properties.symbolize_keys!
    self.virtual_server_images.create!(
      # 初期登録時、default 値として name には一意な provided_id を name へ登録します
      :name => properties[:aws_id],
      :provided_id => properties.delete(:aws_id),
      :provided_description => properties.delete(:description))
  end

  def create_virtual_server_image_hashs(hashs)
    created_ids = []
    hashs.each do |hash|
      image = create_virtual_server_image_hash(hash)
      created_ids << image.id
    end
    created_ids
  end

  # virtual_server
  def differential_update_virtual_server_hash(hash)
    properties = hash.symbolize_keys.dup
    properties.symbolize_keys!
    virtual_server = self.virtual_servers.where(:provided_id => properties[:aws_instance_id]).first
    virtual_server.provided_id = properties.delete(:aws_instance_id)
    virtual_server.provided_image_id = properties.delete(:aws_image_id)
    virtual_server.provided_type_id = properties.delete(:aws_instance_type)
    virtual_server.status = properties.delete(:aws_state)
    properties.each do |key, val|
      value =  properties.delete(key)
      unless val.to_s == value.to_s
        if virtual_server.properties[key.to_sym]
          virtual_server.properties[key.to_sym] = value
        else
          virtual_server.properties[key.to_s] = value
        end
      end
    end
    virtual_server.save! if virtual_server.changed?
  end

  def differential_update_virtual_server_hashs(hashs)
    updated_servers = []
    hashs.each do |hash|
      server = differential_update_virtual_server_hash(hash)
      updated_servers << server
    end
    updated_servers
  end

  def create_virtual_server_hash(hash)
    properties = hash.dup
    properties.symbolize_keys!
    self.virtual_servers.create!(
      # 初期登録時、default 値として name には一意な provided_id を name へ登録します
      :name => properties[:aws_instance_id],
      :provided_id => properties.delete(:aws_instance_id),
      :provided_image_id => properties.delete(:aws_image_id),
      :provided_type_id => properties.delete(:aws_instance_type),
      :status => properties.delete(:aws_state),
      :addresses => properties.delete(:ip_address),
      :address_order => properties.delete(:private_ip_address),
      :properties => properties)
  end

  def create_virtual_server_hashs(hashs)
    created_ids = []
    hashs.each do |hash|
      server = create_virtual_server_hash(hash)
      created_ids << server.id
    end
    created_ids
  end

  # wakame api for tama

  # wakame api からの戻り値がのキーが文字列だったりシンボルだったりで統一されてないので暫定対応で
  # stringify_keys してます

  def hash_key_convert(hash, convert)
    case convert
    when :string
      hash.map(&:stringify_keys!)
    when :symbol
      hash.map(&:symbolize_keys!)
    end
    hash
  end

  def describe_instance_specs_for_api(uuids = [], option = {})
    result = connect do |conn|
      conn.describe_instance_specs(uuids)
    end
    hash_key_convert(result, option[:convert])
  end

  def describe_host_nodes_for_api(uuids = [], option = {})
    result = connect do |conn|
      conn.describe_host_nodes(uuids)
    end
    hash_key_convert(result, option[:convert])
  end

  def describe_instances_for_api(uuids = [], option = {})
    result = connect do |conn|
      conn.describe_instances(uuids)
    end
    hash_key_convert(result, option[:convert])
  end

  def describe_images_for_api(uuids = [], option = {})
    result = connect do |conn|
      conn.describe_images(uuids)
    end
    hash_key_convert(result, option[:convert])
  end

  def run_instances_for_api(uuids = [], option = {})
    result = connect do |conn|
      conn.run_instances(uuids)
    end
    hash_key_convert(result, option[:convert])
  end

  def terminate_instances_for_api(uuids = [], option = {})
    result = connect do |conn|
      conn.terminate_instances(uuids)
    end
    hash_key_convert(result, option[:convert])
  end

  private

  def address_order
    @@address_order ||= ['private_ip_address'.freeze].freeze
  end

  def connect
    connection = nil
    if self.connection_settings[:test] || self.connection_settings["test"]
      options = self.connection_settings[:options].symbolize_keys
      connection = ::Tama::Controllers::ControllerFactory.create_controller(:test)

      connection.describe_instances_file =
        File.expand_path(options[:describe_instances_file]) if options[:describe_instances_file]
      connection.describe_images_file =
        File.expand_path(options[:describe_images_file]) if options[:describe_images_file]
      connection.run_instances_file =
        File.expand_path(options[:run_instances_file]) if options[:run_instances_file]
      connection.terminate_instances_file =
        File.expand_path(options[:terminate_instances_file]) if options[:terminate_instances_file]
      connection.describe_host_nodes_file  =
        File.expand_path(options[:describe_host_nodes_file]) if options[:describe_host_nodes_file]
      connection.describe_instance_specs_file =
        File.expand_path(options[:describe_instance_specs_file]) if options[:describe_instance_specs_file]
    else
      h = [
        :account, :host, :port, :protocol, :private_network_data,
      ].inject({}) {|r, i|
        r.update i => self.connection_settings[i] || self.connection_settings[i.to_s]
      }
      connection = ::Tama::Controllers::ControllerFactory.create_controller(
        h[:account],
        nil,
        nil,
        nil,
        h[:host],
        h[:port],
        h[:protocol]
        )
    end
    yield connection
  end

end
