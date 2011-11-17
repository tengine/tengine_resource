# -*- coding: utf-8 -*-
class Tengine::Resource::Provider::Wakame < Tengine::Resource::Provider::Ec2

  field :connection_settings, :type => Hash

  # virtual_server_type
  def differential_update_virtual_server_type_hash(hash)
    virtual_server_type = self.virtual_server_types.where(:provided_id => hash[:id]).first
    properties = hash.dup
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
    physical_server = self.physical_servers.where(:provided_id => hash[:id]).first
    properties = hash.dup
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

  # virtual_server
  def differential_update_virtual_server_hash(hash)
    virtual_server = self.virtual_servers.where(:provided_id => hash[:aws_instance_id]).first
    properties = hash.dup
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
    self.virtual_servers.create!(
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
      server = create_virtual_server_hash(hash)
      created_ids << server.id
    end
    created_ids
  end

  def create_virtual_servers hash
    #  0  (使用するAPI)   RightAws::Ec2#run_instances Tama::Tama#run_instances   
    #  1  image_id  仮想サーバイメージ  仮想サーバイメージのprovided_id 仮想サーバイメージのprovided_id  
    #  2  min_count 最小起動台数  指定された起動台数  指定された起動台数  max_countと同じ
    #  3  max_count 最大起動台数  指定された起動台数  指定された起動台数  min_countと同じ
    #  4  group_ids セキュリティグループの配列  (画面で入力)  (空の配列)   
    #  5  key_name  起動した仮想サーバにrootでアクセスできるキー名  (画面で入力)  別途設定された文字列 例: “ssh-xxxxx”   
    #  6  user_data 起動した仮想サーバから参照可能なデータ  (空の文字列)  (空の文字列)   
    #  7  addressing_type (deprecatedなパラメータ)  nil nil  
    #  8  instance_type 仮想サーバタイプ  (画面で入力した仮想サーバタイプのprovided_id) (画面で入力した仮想サーバタイプのprovided_id)  
    #  9  kernel_id カーネル  (画面で入力)  nil  
    # 10  ramdisk_id  カーネル  (画面で入力)  nil  
    # 11  availability_zone 起動するデータセンター  (画面で入力)  仮想サーバを起動する物理サーバのprovided_id  
    # 12  block_device_mappings   nil nil
    count = hash.delete :count
    ps    = hash.delete :physical_server
    raise ArgumentError, "count missing, how many?" unless count
    raise ArgumentError, "physical_server missing, where?" unless ps
    hash[:min_count]         = count
    hash[:max_count]         = count
    hash[:group_ids]         = []
    hash[:key_name]          = self.properties[:key_name]
    hash[:kernel_id]         = nil
    hash[:ramdisk_id]        = nil
    hash[:availability_zone] = ps.provided_id

    super
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
      instance_spec = instance_specs.detect { |instance_spec| instance_spec[:id] == old_server_type.provided_id }
      instance_spec = instance_spec.symbolize_keys if instance_spec

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
      host_node = host_nodes.detect { |host_node| host_node[:id] == old_server.provided_id }
      host_node = host_node.symbolize_keys if host_node

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
      instance = instances.detect { |instance| instance[:aws_instance_id] == old_server.provided_id }
      instance = instance.symbolize_keys if instance

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
  end


  private

  def instance_specs_from_api(uuids = [])
    connect do |conn|
      conn.show_instance_specs(uuids)
    end
  end

  def host_nodes_from_api
    connect do |conn|
      conn.show_host_nodes
    end
  end

  def instances_from_api(uuids = [])
    connect do |conn|
      conn.describe_instances(uuids)
    end
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

end
