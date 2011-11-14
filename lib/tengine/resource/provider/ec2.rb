# -*- coding: utf-8 -*-
class Tengine::Resource::Provider::Ec2 < Tengine::Resource::Provider
  belongs_to :credential, :class_name => "Tengine::Resource::Credential"
  validates_presence_of :credential

  def update_physical_servers
    credential.connect do |conn|
      # ec2.describe_availability_zones  #=> [{:region_name=>"us-east-1",
      #                                        :zone_name=>"us-east-1a",
      #                                        :zone_state=>"available"}, ... ]
      # http://docs.amazonwebservices.com/AWSEC2/latest/APIReference/index.html?ApiReference-query-DescribeAvailabilityZones.html
      hashs = conn.describe_availability_zones.map do |hash|
        {
          :provided_id => hash[:zone_name],
          :name    => hash[:zone_name],
          :status => hash[:zone_state],
        }
      end
      update_physical_servers_by(hashs)
    end
  end

  def update_virtual_servers
    credential.connect do |conn|
      # http://rightscale.rubyforge.org/right_aws_gem_doc/
      # ec2.describe_instances #=>
      #   [{:aws_image_id       => "ami-e444444d",
      #     :aws_reason         => "",
      #     :aws_state_code     => "16",
      #     :aws_owner          => "000000000888",
      #     :aws_instance_id    => "i-123f1234",
      #     :aws_reservation_id => "r-aabbccdd",
      #     :aws_state          => "running",
      #     :dns_name           => "domU-12-34-67-89-01-C9.usma2.compute.amazonaws.com",
      #     :ssh_key_name       => "staging",
      #     :aws_groups         => ["default"],
      #     :private_dns_name   => "domU-12-34-67-89-01-C9.usma2.compute.amazonaws.com",
      #     :aws_instance_type  => "m1.small",
      #     :aws_launch_time    => "2008-1-1T00:00:00.000Z"},
      #     :aws_availability_zone => "us-east-1b",
      #     :aws_kernel_id      => "aki-ba3adfd3",
      #     :aws_ramdisk_id     => "ari-badbad00",
      #      ..., {...}]
      # http://docs.amazonwebservices.com/AWSEC2/latest/APIReference/index.html?ApiReference-query-DescribeInstances.html
      hashs = conn.describe_instances.map do |hash|
        result = {
          :provided_id => hash.delete(:aws_instance_id),
          :provided_image_id => hash.delete(:aws_image_id),
          :status => hash.delete(:aws_state),
        }
        hash.delete(:aws_state_code)
        result[:properties] = hash
        result[:addresses] = {
          :dns_name        => hash.delete(:dns_name),
          :ip_address      => hash.delete(:ip_address),
          :private_dns_name => hash.delete(:private_dns_name),
          :private_ip_address => hash.delete(:private_ip_address),
        }
        result
      end
      update_virtual_servers_by(hashs)
    end
  end

  def update_virtual_server_images
    credential.connect do |conn|
      hashs = conn.describe_images.map do |hash|
        { :provided_id => hash.delete(:aws_id), }
      end
      update_virtual_server_images_by(hashs)
    end
  end

  def create_virtual_servers hash
    #  0	(使用するAPI)	 	RightAws::Ec2#run_instances	Tama::Tama#run_instances	 
    #  1	image_id	仮想サーバイメージ	仮想サーバイメージのprovided_id	仮想サーバイメージのprovided_id	 
    #  2	min_count	最小起動台数	指定された起動台数	指定された起動台数	max_countと同じ
    #  3	max_count	最大起動台数	指定された起動台数	指定された起動台数	min_countと同じ
    #  4	group_ids	セキュリティグループの配列	(画面で入力)	(空の配列)	 
    #  5	key_name	起動した仮想サーバにrootでアクセスできるキー名	(画面で入力)	別途設定された文字列 例: “ssh-xxxxx”	 
    #  6	user_data	起動した仮想サーバから参照可能なデータ	(空の文字列)	(空の文字列)	 
    #  7	addressing_type	(deprecatedなパラメータ)	nil	nil	 
    #  8	instance_type	仮想サーバタイプ	(画面で入力した仮想サーバタイプのprovided_id)	(画面で入力した仮想サーバタイプのprovided_id)	 
    #  9	kernel_id	カーネル	(画面で入力)	nil	 
    # 10	ramdisk_id	カーネル	(画面で入力)	nil	 
    # 11	availability_zone	起動するデータセンター	(画面で入力)	仮想サーバを起動する物理サーバのprovided_id	 
    # 12	block_device_mappings	 	nil	nil
    vi = hash.delete :virtual_server_image
    vt = hash.delete :virtual_server_type
    image_id              = vi.provided_id
    min_count             = hash[:min_count]
    max_count             = hash[:max_count]
    group_ids             = hash[:group_ids]
    key_name              = hash[:key_name]
    user_data             = ""
    addressing_type       = nil
    instance_type         = vt.provided_id
    kernel_id             = hash[:kernel_id]
    ramdisk_id            = hash[:ramdisk_id]
    availability_zone     = hash[:availability_zone]
    block_device_mappings = nil

    credential.connect {|conn|
      a = conn.run_instances(
        image_id,
        min_count,
        max_count,
        group_ids,
        key_name,
        user_data,
        addressing_type,
        instance_type,
        kernel_id,
        ramdisk_id,
        availability_zone,
        block_device_mappings
      ).map {|hash|
        hash.delete(:aws_state_code)
        name = hash.delete(:aws_instance_id)
        {
          :name                 => name,
          :provided_id          => name,
          :provided_image_id    => hash.delete(:aws_image_id),
          :status               => hash.delete(:aws_state),
          :properties           => hash,
          :addresses            => {
            :dns_name           => hash.delete(:dns_name),
            :ip_address         => hash.delete(:ip_address),
            :private_dns_name   => hash.delete(:private_dns_name),
            :private_ip_address => hash.delete(:private_ip_address),
          },
        }
      }

      return a.map {|i|
        self.virtual_servers.create(i)
      }
    }
  end

  def terminate_virtual_servers servers
    credential.connect do |conn|
      # http://rightscale.rubyforge.org/right_aws_gem_doc/classes/RightAws/Ec2.html#M000287
      # http://docs.amazonwebservices.com/AWSEC2/latest/APIReference/ApiReference-query-TerminateInstances.html
      conn.terminate_instances(servers.map {|i| i.provided_id }).map do |hash|
        serv = self.virtual_servers.where(:provided_id => hash[:aws_instance_id]).first
        serv.update_attributes(:status => hash[:aws_current_state_name]) if serv
        serv
      end
    end    
  end
end
