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
    # APIからの仮想サーバタイプ情報を取得
    instance_specs = instance_specs_from_api

    create_instance_specs = []
    update_instance_specs = []
    destroy_server_types = []

    # 仮想イメージタイプの取得
    old_server_types = self.virtual_server_types
    old_server_types.each do |old_server_type|
      instance_spec = instance_specs.detect do |instance_spec|
        (instance_spec[:id] || instance_spec["id"]) == old_server_type.provided_id
      end

      if instance_spec
        # APIで取得したサーバタイプと一致するものがあれば更新対象
        update_instance_specs << instance_spec
      else
        # APIで取得したサーバタイプと一致するものがなければ削除対象
        destroy_server_types << old_server_type
      end
    end
    # APIで取得したサーバタイプがTengine上に存在しないものであれば登録対象
    create_instance_specs = instance_specs - update_instance_specs

    # 更新
    self.differential_update_virtual_server_type_hashs(update_instance_specs) unless update_instance_specs.empty?
    # 登録
    self.create_virtual_server_type_hashs(create_instance_specs) unless create_instance_specs.empty?
    # 削除
    destroy_server_types.each { |target| target.destroy }
  end

  # 物理サーバの監視
  def physical_server_watch
    # APIからの物理サーバ情報を取得
    host_nodes = host_nodes_from_api

    create_host_nodes = []
    update_host_nodes = []
    destroy_servers = []

    # 物理サーバの取得
    old_servers = self.physical_servers
    old_servers.each do |old_server|
      host_node = host_nodes.detect do |host_node|
        (host_node[:id] || host_node["id"]) == old_server.provided_id
      end

      if host_node
        update_host_nodes << host_node
      else
        destroy_servers << old_server
      end
    end
    create_host_nodes = host_nodes - update_host_nodes

    self.differential_update_physical_server_hashs(update_host_nodes) unless update_host_nodes.empty?
    self.create_physical_server_hashs(create_host_nodes) unless create_host_nodes.empty?
    destroy_servers.each { |target| target.destroy }
  end

  # 仮想サーバの監視
  def virtual_server_watch
    # APIからの仮想サーバ情報を取得
    instances = instances_from_api

    create_instances = []
    update_instances = []
    destroy_servers = []

    # 仮想サーバの取得
    old_servers = self.virtual_servers
    old_servers.each do |old_server|
      instance = instances.detect do |instance|
        (instance[:aws_instance_id] || instance["aws_instance_id"]) == old_server.provided_id
      end

      if instance
        update_instances << instance
      else
        destroy_servers << old_server
      end
    end
    create_instances = instances - update_instances

    self.differential_update_virtual_server_hashs(update_instances) unless update_instances.empty?
    self.create_virtual_server_hashs(create_instances) unless create_instances.empty?
    destroy_servers.each { |target| target.destroy }
  end

  # 仮想サーバイメージの監視
  def virtual_server_image_watch
    # APIからの仮想サーバイメージ情報を取得
    images = images_from_api

    create_images = []
    update_images = []
    destroy_server_images = []

    # 仮想サーバの取得
    old_images = self.virtual_server_images
    old_images.each do |old_image|
      image = images.detect do |image|
        (image[:aws_id] || image["aws_id"]) == old_image.provided_id
      end

      if image
        update_images << image
      else
        destroy_server_images << old_image
      end
    end
    create_images = images - update_images

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
    physical_server.name = properties.delete(:name)
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
      :name => properties.delete(:name),
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
      # defaultをaws_idにして良いか検討
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
      # defaultをインスタンスIDにして良いか検討
      :name => properties.delete(:aws_instance_id),
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
      puts
      puts "#"*10
      puts hash["aws_instance_id"]
      puts hash[:aws_instance_id]
      server = create_virtual_server_hash(hash)
      created_ids << server.id
    end
    created_ids
  end

  private

  def address_order
    @@address_order ||= ['private_ip_address'.freeze].freeze
  end

  def connect
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
    yield connection
  end

  def instance_specs_from_api(uuids = [])
    connect do |conn|
      conn.describe_instance_specs(uuids)
    end
#     # dummy
#     dummy_ret = [{
#         "cpu_cores"=>1,
#         "memory_size"=>256,
#         "arch"=>"x86_64",
#         "hypervisor"=>"kvm",
#         "updated_at"=>"2011-10-28T02:58:57Z",
#         "account_id"=>"a-shpoolxx",
#         "vifs"=>"--- \neth0: \n  :bandwidth: 100000\n  :index: 0\n",
#         "quota_weight"=>1.0,
#         "id"=>"is-demospec",
#         "created_at"=>"2011-10-28T02:58:57Z",
#         "drives"=>
#         "--- \nephemeral1: \n  :type: :local\n  :size: 100\n  :index: 0\n",
#         "uuid"=>"is-demospec"
#       }]
  end

  def host_nodes_from_api
    connect do |conn|
      conn.describe_host_nodes
    end
#     # dummy
#     dummy_ret = [{
#         "status"=>"online",
#         "updated_at"=>"2011-10-18T03:53:24Z",
#         "account_id"=>"a-shpoolxx",
#         "offering_cpu_cores"=>100,
#         "offering_memory_size"=>400000,
#         "arch"=>"x86_64",
#         "hypervisor"=>"kvm",
#         "created_at"=>"2011-10-18T03:53:24Z",
#         "name"=>"dummyhost",
#         "uuid"=>"hp-demohost",
#         "id"=>"hp-demohost"
#       }]
  end

  def instances_from_api(uuids = [])
    connect do |conn|
      conn.describe_instances(uuids)
    end
  end

  def images_from_api(uuids = [])
    connect do |conn|
      conn.describe_images(uuids)
    end
  end

end
