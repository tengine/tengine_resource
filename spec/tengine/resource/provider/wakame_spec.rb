# -*- coding: utf-8 -*-
require 'spec_helper'
require 'apis/ec2'
require 'apis/wakame'
require 'controllers/controller'

describe Tengine::Resource::Provider::Wakame do
  subject {
    Tengine::Resource::Provider::Wakame.delete_all(:name => 'tama0001')
    Tengine::Resource::Provider::Wakame.create(
      :name => "tama0001",
      :description => "provided by wakame / tama",
      :connection_settings => {
        :account => "a-shpoolxx",
        :host => "192.168.2.22",
        :port => 9001,
        :protocol => "https",
      },
      :properties => {
        :key_name => "ssh-xxxxx"
      }
    )
  }

  context "仮想マシンの起動" do
    before do
      c = mock(::Tama::Controllers::ControllerFactory.allocate)
      ::Tama::Controllers::ControllerFactory.
        stub(:create_controller).
        with("a-shpoolxx", nil, nil, nil, "192.168.2.22", 9001, "https").
        and_return(c)
      c.stub(:run_instances).
        with("wmi-lucid5", 1, 1, [], "ssh-xxxxx", "", nil, "is-small", nil, nil, "foo-dc", nil).
        and_return([{
          :aws_image_id       => "wmi-lucid5",
          :aws_reason         => "",
          :aws_state_code     => "0",
          :aws_owner          => "000000000888",
          :aws_instance_id    => "i-123f1234",
          :aws_reservation_id => "r-aabbccdd",
          :aws_state          => "pending",
          :dns_name           => "",
          :ssh_key_name       => "ssh-xxxxxx",
          :aws_groups         => [""],
          :private_dns_name   => "",
          :aws_instance_type  => "is-small",
          :aws_launch_time    => "2008-1-1T00:00:00.000Z",
          :aws_ramdisk_id     => "",
          :aws_kernel_id      => "",
          :ami_launch_index   => "0",
          :aws_availability_zone => "",
        }])
    end

    it "1台の起動" do
      vi = subject.virtual_server_images.create(:provided_id => "wmi-lucid5")
      vt = subject.virtual_server_types.create(:provided_id => "is-small")
      ps = subject.physical_servers.create(:provided_id => "foo-dc")
      vs = subject.create_virtual_servers({
        :virtual_server_image => vi,
        :virtual_server_type => vt,
        :physical_server => ps,
        :count => 1,
      })
      vs.count.should == 1
      v = vs.first
      v.should be_valid
      v.status.should == "pending"
      v.provided_image_id.should == vi.provided_id
    end
  end

  context "仮想マシンの停止" do
    before do
      Tengine::Resource::VirtualServer.delete_all
      c = mock(::Tama::Controllers::ControllerFactory.allocate)
      ::Tama::Controllers::ControllerFactory.
        stub(:create_controller).
        with("a-shpoolxx", nil, nil, nil, "192.168.2.22", 9001, "https").
        and_return(c)
      c.stub(:terminate_instances).
        with(["i-f222222d"]).
        and_return([{
         :aws_shutdown_state      => nil,
         :aws_instance_id         => "i-f222222d",
         :aws_shutdown_state_code => nil,
         :aws_prev_state          => nil,
         :aws_prev_state_code     => nil,
       }])
      c.stub(:terminate_instances).
        with(["i-f222222d", "i-f222222e"]).
        and_return([{
         :aws_shutdown_state      => nil,
         :aws_instance_id         => "i-f222222d",
         :aws_shutdown_state_code => nil,
         :aws_prev_state          => nil,
         :aws_prev_state_code     => nil,
       }, {
         :aws_shutdown_state      => nil,
         :aws_instance_id         => "i-f222222e",
         :aws_shutdown_state_code => nil,
         :aws_prev_state          => nil,
         :aws_prev_state_code     => nil,
       }])
    end

    it "1台の停止" do
      vs = subject.virtual_servers.create(:provided_id => 'i-f222222d', :name => 'i-f222222d')
      va = subject.terminate_virtual_servers([vs])
      va.count.should == 1
      v = va[0]
      v.should_not be_nil
      v.should be_valid
      v.provided_id.should == 'i-f222222d'
    end

    it "複数台の停止" do
      v1 = subject.virtual_servers.create(:provided_id => 'i-f222222d', :name => 'i-f222222d')
      v2 = subject.virtual_servers.create(:provided_id => 'i-f222222e', :name => 'i-f222222e')
      va = subject.terminate_virtual_servers([v1 ,v2])
      va.count.should == 2
      va[0].should_not be_nil
      va[0].should be_valid
      va[0].provided_id.should == 'i-f222222d'
      va[1].should_not be_nil
      va[1].should be_valid
      va[1].provided_id.should == 'i-f222222e'
    end
  end
end
