# -*- coding: utf-8 -*-
class Tengine::Resource::Provider::Wakame < Tengine::Resource::Provider::Ec2

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
  private

  def connect
    h = [
      :account, 
      :ec2_host, :ec2_port, :ec2_protocol,
      :wakame_host, :wakame_port, :wakame_protocol,
    ].inject({}) {|r, i|
      r.update i => self.connection_settings[i]
    }
    connection = ::Tama::Controllers::ControllerFactory.create_controller(
      h[:account],
      h[:ec2_host],
      h[:ec2_port],
      h[:ec2_protocol],
      h[:wakame_host],
      h[:wakame_port],
      h[:wakame_protocol],
    )
    yield connection
  end
end
