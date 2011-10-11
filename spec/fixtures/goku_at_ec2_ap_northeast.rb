# -*- coding: utf-8 -*-

class GokuAtEc2ApNortheast
  # # memoize については http://wota.jp/ac/?date=20081025#p11 などを参照してください
  # extend ActiveSupport::Memoizable

  def provider
    Tengine::Resource::Provider::Ec2.find_or_create_by_name!({
        :name => "goku_at_ec2_ap-northeast-1",
        :credential_id => self.goku_ec2.id
      })
  end

  def goku_ec2
    Tengine::Resource::Credential.find_or_create_by_name!(
      :name => "goku_ec2",
      :auth_type_key => :ec2_access_key,
      :auth_values => {
        :access_key => '12345',
        :secret_access_key => '1234567',
        :default_region => 'ap-northeast-1'
      })
  end

  def goku_ssh_pw
    Tengine::Resource::Credential.find_or_create_by_name!(
      :name => "goku_ssh_pw",
      :auth_type_key => :ssh_password,
      :auth_values => {
        :username => 'goku',
        :password => 'dragonball'
      })
  end

  def physical_servers
    [availability_zone(1), availability_zone(2)]
  end

  def availability_zone(idx)
    name = "ap-notrheast-1" + ("a".ord - 1 + idx).chr
    Tengine::Resource::PhysicalServer.find_or_create_by_name!(
      :name => name, :provided_name => name, :status => "available")
  end

  def virtual_server_images
    [
      hadoop_image,
      mysql_image,
      rails_image
    ]
  end

  def hadoop_image
    provider.virtual_server_images.find_or_create_by_name!(
      :name => "hadoop_image1",
      :provided_name => "ami-10000001")
  end

  def mysql_image
    provider.virtual_server_images.find_or_create_by_name!(
      :name => "mysql_image1",
      :provided_name => "ami-10000002")
  end

  def rails_image
    provider.virtual_server_images.find_or_create_by_name!(
      :name => "rails_image1",
      :provided_name => "ami-10000003")
  end

  def virtual_servers
    [
      hadoop_master_node,
      hadoop_slave_node(1),
      hadoop_slave_node(2),
      hadoop_slave_node(3),
      mysql_master,
      mysql_slave(1),
      mysql_slave(2),
      rails_server(1)
    ]
  end

  def hadoop_master_node
    provider.virtual_servers.find_or_create_by_name!(
      hostnames_and_ips(1).update(
        :provided_image_name => hadoop_image.provided_name,
        :host => availability_zone(1), :status => "available",
        :name => "hadoop_master_node", :provided_name => "i-10000001"))
  end

  def hadoop_slave_node(idx)
    provider.virtual_servers.find_or_create_by_name!(
      hostnames_and_ips(idx + 10).update(
        :provided_image_name => hadoop_image.provided_name,
        :host => availability_zone(1), :status => "available",
        :name => "hadoop_slave_node#{idx}", :provided_name => "i-1000001#{idx}"))
  end

  def mysql_master
    provider.virtual_servers.find_or_create_by_name!(
      hostnames_and_ips(20).update(
        :provided_image_name => mysql_image.provided_name,
        :host => availability_zone(1), :status => "available",
        :name => "mysql_master", :provided_name => "i-10000020"))
  end

  def mysql_slave(idx)
    provider.virtual_servers.find_or_create_by_name!(
      hostnames_and_ips(idx + 20).update(
        :provided_image_name => mysql_image.provided_name,
        :host => availability_zone(1), :status => "available",
        :name => "mysql_slave#{idx}", :provided_name => "i-1000002#{idx}"))
  end

  def rails_server(idx)
    provider.virtual_servers.find_or_create_by_name!(
      hostnames_and_ips(idx + 30).update(
        :provided_image_name => rails_image.provided_name,
        :host => availability_zone(1), :status => "available",
        :name => "rails#{idx}", :provided_name => "i-1000003#{idx}"))
  end

  private
  def hostnames_and_ips(idx)
    {
      :public_hostname => "ec2-184-72-20-#{idx}.ap-northeast-1.compute.amazonaws.com",
      :public_ipv4         => "184.72.20.#{idx}",
      :private_hostname => "ip-10-162-153-#{idx}.ap-northeast-1.compute.internal",
      :private_ipv4     =>    "10.162.153.#{idx}",
    }
  end

end
