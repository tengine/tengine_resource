# -*- coding: utf-8 -*-
require 'spec_helper'
require 'eventmachine'
require 'amqp'
require 'tengine/mq/suite'
require 'apis/wakame'
require 'controllers/controller'

describe Tengine::Resource::Provider::Wakame do

  before do
    class Tengine::Resource::VirtualServer < Tengine::Resource::Server
      def destroy
        $stdout.puts "invoked"
        super
      end
    end
  end

  after do
    Tengine::Resource::VirtualServer.class_eval { remove_method :destroy }
  end

  before do
    Tengine::Resource::Provider.delete_all
    Tengine::Resource::PhysicalServer.delete_all
    Tengine::Resource::VirtualServer.delete_all
    @provider = Tengine::Resource::Provider::Wakame.create!({
        :name => "wakame-vdc",
        :description => "",
        :properties => {
          :key_name => "ssh-xxxxx"
        },
        :polling_interval => 5,
        :connection_settings => {
          :account => "tama_account1",
          :ec2_host => "10.10.10.10",
          :ec2_port => 80,
          :ec2_protocol => "https",
          :wakame_host => "192.168.0.10",
          :wakame_port => 8080,
          :wakame_protocol => "http",
        },
      })
    @physical_server_wakame = @provider.physical_servers.create!({
        :name => "demohost",
        :description => "",
        :provided_id => "hp-demohost",
        :status => "online",
        :addresses => {},
        :address_order => [],
        :cpu_cores => 100,
        :memory_size => 400000,
        :properties => {
          :uuid => "hp-demohost",
          :account_id => "a-shpoolxx",
          :arch => "x86_64",
          :hypervisor => "kvm",
          :created_at => "2011-10-18T03:53:24Z",
          :updated_at => "2011-10-18T03:53:24Z",
        }
      })
    @provider.virtual_servers.create!({
        :name => "vhost",
        :description => "",
        :provided_id => "i-jria301q",
        :provided_image_id => "wmi-lucid5",
        :provided_type_id => "is-demospec",
        :host_server => @physical_server_wakame,
        :status => "running",
        :addresses => {
          "private_ip_address" => "192.168.2.188",
          "nw-data" => "192.168.2.188",
        },
        :address_order => ["private_ip_address"],
        :properties => {
          :aws_kernel_id => "",
          :aws_launch_time => "2011-10-18T06:51:16Z",
          :tags => {},
          :aws_reservation_id => "",
          :aws_owner => "a-shpoolxx",
          :instance_lifecycle => "",
          :block_device_mappings => [{
              :ebs_volume_id => "",
              :ebs_status => "",
              :ebs_attach_time => "",
              :ebs_delete_on_termination => false,
              :device_name => ""
            }],
          :ami_launch_index => "",
          :root_device_name => "",
          :aws_ramdisk_id => "",
          :aws_availability_zone => "hp-demohost",
          :aws_groups => nil,
          :spot_instance_request_id => "",
          :ssh_key_name => nil,
          :virtualization_type => "",
          :placement_group_name => "",
          :requester_id => "",
          :aws_product_codes => [],
          :client_token => "",
          :architecture => "x86_64",
          :aws_state_code => 0,
          :root_device_type => "",
          :monitoring_state => "",
          :aws_reason => ""
        }
      })
  end

  describe :sync_virtual_servers do
    before do
      @tama_controller_factory = mock(::Tama::Controllers::ControllerFactory.allocate)
      ::Tama::Controllers::ControllerFactory.
        stub(:create_controller).
        with("tama_account1", "10.10.10.10", 80, "https", "192.168.0.10", 8080, "http").
        and_return(@tama_controller_factory)
    end

    it "削除の通知が何度も行われてしまう" do
      @tama_controller_factory.stub(:describe_instances).with([]).and_return([])

      # 一度も呼び出されない
      @provider.should_not_receive(:dirrefential_update_virtual_server_hashs)
      @provider.should_not_receive(:create_virtual_server_hashs)
      # 一度だけ呼び出される
      $stdout.should_receive(:puts).with("invoked").once

      3.times do
        @provider.virtual_server_watch
      end
    end
  end

end
