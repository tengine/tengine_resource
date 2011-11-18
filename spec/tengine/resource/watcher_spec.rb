# -*- coding: utf-8 -*-
require 'spec_helper'
require 'eventmachine'
require 'amqp'
require 'tengine/mq/suite'
require 'apis/wakame'
require 'controllers/controller'

describe Tengine::Resource::Watcher do

  describe :initialize do
    it "default" do
      Tengine::Core::MethodTraceable.stub(:disabled=)
      watcher = Tengine::Resource::Watcher.new
      watcher.config[:tengined]['daemon'].should == false
      watcher.config[:tengined][:daemon].should == false
      watcher.config[:event_queue][:connection][:host].should == "localhost"
      watcher.config['event_queue']['connection']['host'].should == "localhost"
      watcher.config[:event_queue][:queue][:name].should == "tengine_event_queue"
      watcher.config['event_queue']['queue']['name'].should == "tengine_event_queue"
      watcher.config['heartbeat']['resourcew'].should == {"interval"=>30, "expire"=>120}
    end
  end

  describe :sender do
    before do
      @watcher = Tengine::Resource::Watcher.new
      EM.should_receive(:run).and_yield

      # コネクションの mock を生成
      mock_conn = mock(:connection)
      AMQP.should_receive(:connect).with(an_instance_of(Hash)).and_return(mock_conn)
      mock_conn.should_receive(:on_tcp_connection_loss)
      mock_conn.should_receive(:after_recovery)
      mock_conn.should_receive(:on_closed)
    end

    it "生成したmq_suiteが設定されている" do
      mock_mq = Tengine::Mq::Suite.new(@watcher.config[:event_queue])
      Tengine::Mq::Suite.should_receive(:new).
        with(@watcher.config[:event_queue]).and_return(mock_mq)

      @watcher.sender.should_receive(:wait_for_connection)
      @watcher.start
      @watcher.mq_suite.should == mock_mq
    end

    it "生成したsenderが設定されている" do
      mock_mq = Tengine::Mq::Suite.new(@watcher.config[:event_queue])
      Tengine::Mq::Suite.should_receive(:new).
        with(@watcher.config[:event_queue]).and_return(mock_mq)

      mock_sender = mock(:sender)
      Tengine::Event::Sender.should_receive(:new).with(mock_mq).and_return(mock_sender)

      @watcher.sender.should_receive(:wait_for_connection)
      @watcher.start
      @watcher.sender.should == mock_sender
    end
  end

  describe :start do
    before do
      @watcher = Tengine::Resource::Watcher.new
      EM.should_receive(:run).and_yield

      # コネクションの mock を生成
      mock_conn = mock(:connection)
      AMQP.should_receive(:connect).with(an_instance_of(Hash)).and_return(mock_conn)
      mock_conn.should_receive(:on_tcp_connection_loss)
      mock_conn.should_receive(:after_recovery)
      mock_conn.should_receive(:on_closed)

      @mock_mq = Tengine::Mq::Suite.new(@watcher.config[:event_queue])
      Tengine::Mq::Suite.should_receive(:new).
        with(@watcher.config[:event_queue]).and_return(@mock_mq)

      Tengine::Resource::Provider.delete_all
      @provider_ec2 = Tengine::Resource::Provider::Ec2.create!({
          :name => "amazon-ec2",
          :description => "",
          :properties => {
          },
          :polling_interval => 5,
          :connection_settings => {
            :access_key => "",
            :secret_access_key => "",
            :options => {
              :server => "ec2.amazonaws.com",
              :port => 443,
              :protocol => "https",
              :multi_thread => false,
              :logger => nil,
              :signature_version => '1',
              :cache => false,
            }
          }
        })
      @provider_wakame = Tengine::Resource::Provider::Wakame.create!({
          :name => "wakame-vdc",
          :description => "",
          :properties => {
            :key_name => "ssh-xxxxx"
          },
          :polling_interval => 5,
          :connection_settings => {
            :account => "test",
            :host => "192.168.0.10",
            :port => 80,
            :protocol => "http",
            :private_network_data => "",
          },
        })
    end

    it "flow" do
      @watcher.sender.should_receive(:wait_for_connection).and_yield
      Tengine::Resource::Provider.should_receive(:all).and_return([@provider_wakame, @provider_ec2])

      @provider_wakame.should_receive(:virtual_server_type_watch)
      EM.should_receive(:add_periodic_timer).with(@provider_wakame.polling_interval).and_yield
      @provider_wakame.should_receive(:physical_server_watch)
      @provider_wakame.should_receive(:virtual_server_watch)
      @provider_wakame.should_receive(:virtual_server_image_watch)

      @provider_ec2.should_receive(:virtual_server_type_watch)
      EM.should_receive(:add_periodic_timer).with(@provider_ec2.polling_interval).and_yield
      @provider_ec2.should_receive(:physical_server_watch)
      @provider_ec2.should_receive(:virtual_server_watch)
      @provider_ec2.should_receive(:virtual_server_image_watch)

      @watcher.start
    end

    # 仮想サーバタイプ
    describe :virtual_server_type_watch do
      before do
        Tengine::Event.default_sender.should_receive(:fire).with(
          "Tengine::Resource::VirtualServerType.created.tengine_resource_watchd",
          anything())

        Tengine::Resource::VirtualServerType.delete_all
        @virtual_server_type_wakame = @provider_wakame.virtual_server_types.create!({
            :provided_id => "is-demospec",
            :caption => "is-demospec",
            :cpu_cores => 2,
            :memory_size => 512,
            :properties => {
              :arch => "x86_64",
              :hypervisor => "kvm",
              :account_id => "a-shpoolxx",
              :vifs => "--- \neth0: \n  :bandwidth: 100000\n  :index: 0\n",
              :quota_weight => "1.0",
              :drives => "--- \nephemeral1: \n  :type: :local\n  :size: 100\n  :index: 0\n",
              :created_at => "2011-10-28T02:58:57Z",
              :updated_at => "2011-10-28T02:58:57Z",
            }
          })

        @watcher.sender.should_receive(:wait_for_connection).and_yield
      end

      context "wakame" do
        before do
          Tengine::Resource::Provider.should_receive(:all).and_return([@provider_wakame])
          EM.should_receive(:add_periodic_timer).with(@provider_wakame.polling_interval)

          @tama_controller_factory = mock(::Tama::Controllers::ControllerFactory.allocate)
          ::Tama::Controllers::ControllerFactory.
            should_receive(:create_controller).
            with("test", nil, nil, nil, "192.168.0.10", 80, "http").
            and_return(@tama_controller_factory)
        end

        it "更新対象があったら更新完了後イベントを発火する" do
          @tama_controller_factory.
            should_receive(:describe_instance_specs).with([]).
            and_return(UPDATE_WAKAME_INSTANCE_SPECS)

          Tengine::Event.default_sender.should_receive(:fire).with(
            "Tengine::Resource::VirtualServerType.updated.tengine_resource_watchd",
            anything())

          @virtual_server_type_wakame.cpu_cores.should == 2
          @virtual_server_type_wakame.memory_size.should == 512

          @watcher.start

          @provider_wakame.reload
          new_server_type = @provider_wakame.virtual_server_types.first
          new_server_type.cpu_cores.should == 1
          new_server_type.memory_size.should == 256
        end

        it "更新対象がなかったらイベントは発火しない" do
          @tama_controller_factory.
            should_receive(:describe_instance_specs).with([]).
            and_return(ORIGINAL_WAKAME_INSTANCE_SPECS)

          Tengine::Event.default_sender.should_not_receive(:fire)

          @virtual_server_type_wakame.cpu_cores.should == 2
          @virtual_server_type_wakame.memory_size.should == 512

          @watcher.start

          @provider_wakame.reload
          new_server_type = @provider_wakame.virtual_server_types.first
          new_server_type.cpu_cores.should == 2
          new_server_type.memory_size.should == 512
        end

        it "登録対象があったら登録完了後イベントを発火する" do
          @tama_controller_factory.
            should_receive(:describe_instance_specs).with([]).
            and_return(CREATE_WAKAME_INSTANCE_SPECS)

          Tengine::Event.default_sender.should_receive(:fire).with(
            "Tengine::Resource::VirtualServerType.created.tengine_resource_watchd",
            anything())

          expect { @watcher.start }.should change(
            @provider_wakame.virtual_server_types, :count).by(1)
        end

        it "削除対象があったら削除完了後イベントを発火する" do
          @tama_controller_factory.
            should_receive(:describe_instance_specs).with([]).
            and_return([])

          Tengine::Event.default_sender.should_receive(:fire).with(
            "Tengine::Resource::VirtualServerType.destroyed.tengine_resource_watchd",
            anything())

          expect { @watcher.start }.should change(
            @provider_wakame.virtual_server_types, :size).by(-1)
        end
      end  # end to wakame

      context "ec2" do
        before do
          Tengine::Resource::Provider.should_receive(:all).and_return([@provider_ec2])
          EM.should_receive(:add_periodic_timer).with(@provider_wakame.polling_interval)
        end

        it "実行されない" do
          @provider_ec2.should_not_receive(:instance_specs_from_api)
          @watcher.start
        end
      end   # end to ec2
    end   # end to :virtual_server_type_watch

    # 物理サーバ
    describe :physical_server_watch do
      before do
        Tengine::Event.default_sender.should_receive(:fire).with(
          "Tengine::Resource::PhysicalServer.created.tengine_resource_watchd",
          anything())

        Tengine::Resource::PhysicalServer.delete_all
        @physical_server_wakame = @provider_wakame.physical_servers.create!({
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

        @watcher.sender.should_receive(:wait_for_connection).and_yield
      end

      context "wakame" do
        before do
          Tengine::Resource::Provider.should_receive(:all).and_return([@provider_wakame])
          @provider_wakame.should_receive(:virtual_server_type_watch)
          EM.should_receive(:add_periodic_timer).with(@provider_wakame.polling_interval).and_yield
          @provider_wakame.should_receive(:virtual_server_watch)
          @provider_wakame.should_receive(:virtual_server_image_watch)

          @tama_controller_factory = mock(::Tama::Controllers::ControllerFactory.allocate)
          ::Tama::Controllers::ControllerFactory.
            should_receive(:create_controller).
            with("test", nil, nil, nil, "192.168.0.10", 80, "http").
            and_return(@tama_controller_factory)
        end

        it "更新対象があったら更新完了後イベントを発火する" do
          @tama_controller_factory.
            should_receive(:describe_host_nodes).and_return(UPDATE_WAKAME_HOST_NODES)

          Tengine::Event.default_sender.should_receive(:fire).with(
            "Tengine::Resource::PhysicalServer.updated.tengine_resource_watchd",
            anything())

          @physical_server_wakame.cpu_cores.should == 100
          @physical_server_wakame.memory_size.should == 400000

          @watcher.start

          @provider_wakame.reload
          new_server = @provider_wakame.physical_servers.first
          new_server.cpu_cores.should == 75
          new_server.memory_size.should == 350000
        end

        it "更新対象がなかったらイベントは発火しない" do
          @tama_controller_factory.
            should_receive(:describe_host_nodes).and_return(ORIGINAL_WAKAME_HOST_NODES)

          Tengine::Event.default_sender.should_not_receive(:fire)

          @physical_server_wakame.cpu_cores.should == 100
          @physical_server_wakame.memory_size.should == 400000

          @watcher.start

          @provider_wakame.reload
          new_server = @provider_wakame.physical_servers.first
          new_server.cpu_cores.should == 100
          new_server.memory_size.should == 400000
        end

        it "登録対象があったら登録完了後イベントを発火する" do
          @tama_controller_factory.
            should_receive(:describe_host_nodes).and_return(CREATE_WAKAME_HOST_NODES)

          Tengine::Event.default_sender.should_receive(:fire).with(
            "Tengine::Resource::PhysicalServer.created.tengine_resource_watchd",
            anything())

          expect { @watcher.start }.should change(
            @provider_wakame.physical_servers, :count).by(1)
        end

        it "削除対象があったら削除完了後イベントを発火する" do
          @tama_controller_factory.
            should_receive(:describe_host_nodes).and_return([])

          Tengine::Event.default_sender.should_receive(:fire).with(
            "Tengine::Resource::PhysicalServer.destroyed.tengine_resource_watchd",
            anything())

          expect { @watcher.start }.should change(
            @provider_wakame.physical_servers, :size).by(-1)
        end
      end   # end to :wakame
    end   # end to :phyical_server_watch

    # 仮想サーバ
    describe :virtual_server_watch do
      before do
        Tengine::Event.default_sender.should_receive(:fire).with(
          "Tengine::Resource::VirtualServer.created.tengine_resource_watchd",
          anything())

        Tengine::Resource::VirtualServer.delete_all
        @virtual_server_wakame = @provider_wakame.virtual_servers.create!({
            :name => "vhost",
            :description => "",
            :provided_id => "i-jria301q",
            :provided_image_id => "wmi-lucid5",
            :provided_type_id => "is-demospec",
            :status => "running",
            :addresses => {
              "nw-data" => ["192.168.2.188"],
              "nw-outside" => ["172.16.0.234"]
            },
            :address_order => ["192.168.2.188"],
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
              :dns_name => {
                "nw-data" => "jria301q.shpoolxx.vdc.local",
                "nw-outside" => "jria301q.shpoolxx.vdc.public"
              },
              :monitoring_state => "",
              :private_dns_name => "jria301q.shpoolxx.vdc.local",
              :aws_reason => ""
            }
          })

        @watcher.sender.should_receive(:wait_for_connection).and_yield
      end

      context "wakame" do
        before do
          Tengine::Resource::Provider.should_receive(:all).and_return([@provider_wakame])
          @provider_wakame.should_receive(:virtual_server_type_watch)
          EM.should_receive(:add_periodic_timer).with(@provider_wakame.polling_interval).and_yield
          @provider_wakame.should_receive(:physical_server_watch)
          @provider_wakame.should_receive(:virtual_server_image_watch)

          @tama_controller_factory = mock(::Tama::Controllers::ControllerFactory.allocate)
          ::Tama::Controllers::ControllerFactory.
            should_receive(:create_controller).
            with("test", nil, nil, nil, "192.168.0.10", 80, "http").
            and_return(@tama_controller_factory)
        end

        it "更新対象があったら更新完了後イベントを発火する" do
          @tama_controller_factory.
            should_receive(:describe_instances).with([]).
            and_return(UPDATE_WAKAME_INSTANCES)

          Tengine::Event.default_sender.should_receive(:fire).with(
            "Tengine::Resource::VirtualServer.updated.tengine_resource_watchd",
            anything())

          @virtual_server_wakame.status.should == "running"

          @watcher.start

          @provider_wakame.reload
          new_server = @provider_wakame.virtual_servers.first
          new_server.status.should == "terminated"
        end

        it "更新対象がなかったらイベントは発火しない" do
          @tama_controller_factory.
            should_receive(:describe_instances).with([]).
            and_return(ORIGINAL_WAKAME_INSTANCES)

          Tengine::Event.default_sender.should_not_receive(:fire)

          @watcher.start
        end

        it "登録対象があったら登録完了後イベントを発火する" do
          @tama_controller_factory.
            should_receive(:describe_instances).with([]).
            and_return(CREATE_WAKAME_INSTANCES)

          Tengine::Event.default_sender.should_receive(:fire).with(
            "Tengine::Resource::VirtualServer.created.tengine_resource_watchd",
            anything())

          expect { @watcher.start }.should change(
            @provider_wakame.virtual_servers, :count).by(1)
        end

        it "削除対象があったら削除完了後イベントを発火する" do
          @tama_controller_factory.
            should_receive(:describe_instances).with([]).
            and_return([])

          Tengine::Event.default_sender.should_receive(:fire).with(
            "Tengine::Resource::VirtualServer.destroyed.tengine_resource_watchd",
            anything())

          expect { @watcher.start }.should change(
            @provider_wakame.virtual_servers, :size).by(-1)
        end
      end  # end to wakame

    end   # end to :virtual_server_watch

    # 仮想サーバイメージ
    describe :virtual_server_image_watch do
      before do
        Tengine::Event.default_sender.should_receive(:fire).with(
          "Tengine::Resource::VirtualServerImage.created.tengine_resource_watchd",
          anything())

        Tengine::Resource::VirtualServerImage.delete_all
        @virtual_server_image_wakame = @provider_wakame.virtual_server_images.create!({
            :name => "vimage",
            :description => "",
            :provided_id => "wmi-lucid6",
            :provided_description => "ubuntu-10.04_with-metadata_kvm_i386.raw volume",
          })
        @watcher.sender.should_receive(:wait_for_connection).and_yield
      end

      context "wakame" do
        before do
          Tengine::Resource::Provider.should_receive(:all).and_return([@provider_wakame])
          @provider_wakame.should_receive(:virtual_server_type_watch)
          EM.should_receive(:add_periodic_timer).with(@provider_wakame.polling_interval).and_yield
          @provider_wakame.should_receive(:physical_server_watch)
          @provider_wakame.should_receive(:virtual_server_watch)

          @tama_controller_factory = mock(::Tama::Controllers::ControllerFactory.allocate)
          ::Tama::Controllers::ControllerFactory.
            should_receive(:create_controller).
            with("test", nil, nil, nil, "192.168.0.10", 80, "http").
            and_return(@tama_controller_factory)
        end

        it "更新対象があったら更新完了後イベントを発火する" do
          @tama_controller_factory.
            should_receive(:describe_images).with([]).
            and_return(UPDATE_WAKAME_IMAGES)

          Tengine::Event.default_sender.should_receive(:fire).with(
            "Tengine::Resource::VirtualServerImage.updated.tengine_resource_watchd",
            anything())

          @virtual_server_image_wakame.provided_description.should ==
            "ubuntu-10.04_with-metadata_kvm_i386.raw volume"

          @watcher.start

          @provider_wakame.reload
          new_image = @provider_wakame.virtual_server_images.first
          new_image.provided_description.should ==
            "ubuntu-10.04_with-metadata_kvm_i386.raw"
        end

        it "更新対象がなかったらイベントは発火しない" do
          @tama_controller_factory.
            should_receive(:describe_images).with([]).
            and_return(ORIGINAL_WAKAME_IMAGES)

          Tengine::Event.default_sender.should_not_receive(:fire)

          @watcher.start
        end

        it "登録対象があったら登録完了後イベントを発火する" do
          @tama_controller_factory.
            should_receive(:describe_images).with([]).
            and_return(CREATE_WAKAME_IMAGES)

          Tengine::Event.default_sender.should_receive(:fire).with(
            "Tengine::Resource::VirtualServerImage.created.tengine_resource_watchd",
            anything())

          expect { @watcher.start }.should change(
            @provider_wakame.virtual_server_images, :count).by(1)
        end

        it "削除対象があったら削除完了後イベントを発火する" do
          @tama_controller_factory.
            should_receive(:describe_images).with([]).
            and_return([])

          Tengine::Event.default_sender.should_receive(:fire).with(
            "Tengine::Resource::VirtualServerImage.destroyed.tengine_resource_watchd",
            anything())

          expect { @watcher.start }.should change(
            @provider_wakame.virtual_server_images, :size).by(-1)
        end
      end  # end to wakame

    end   # end to :virtual_server_image_watch

  end   # end to :start

  ORIGINAL_WAKAME_INSTANCE_SPECS = [{
      :cpu_cores => 2,
      :memory_size => 512,
      :arch => "x86_64",
      :hypervisor => "kvm",
      :updated_at => "2011-10-28T02:58:57Z",
      :account_id => "a-shpoolxx",
      :vifs => "--- \neth0: \n  :bandwidth: 100000\n  :index: 0\n",
      :quota_weight => 1.0,
      :id => "is-demospec",
      :created_at => "2011-10-28T02:58:57Z",
      :drives => "--- \nephemeral1: \n  :type: :local\n  :size: 100\n  :index: 0\n",
      :uuid => "is-demospec"
    }]
  UPDATE_WAKAME_INSTANCE_SPECS = [{
      :cpu_cores => 1,
      :memory_size => 256,
      :arch => "x86_64",
      :hypervisor => "kvm",
      :updated_at => "2011-10-28T02:58:57Z",
      :account_id => "a-shpoolxx",
      :vifs => "--- \neth0: \n  :bandwidth: 100000\n  :index: 0\n",
      :quota_weight => 1.0,
      :id => "is-demospec",
      :created_at => "2011-10-28T02:58:57Z",
      :drives => "--- \nephemeral1: \n  :type: :local\n  :size: 100\n  :index: 0\n",
      :uuid => "is-demospec"
    }]
  CREATE_WAKAME_INSTANCE_SPECS = [{
      :cpu_cores => 2,
      :memory_size => 1024,
      :arch => "x86_64",
      :hypervisor => "kvm",
      :updated_at => "2011-10-28T02:58:57Z",
      :account_id => "b-shpoolxx",
      :vifs => "--- \neth0: \n  :bandwidth: 100000\n  :index: 0\n",
      :quota_weight => 1.0,
      :id => "is-demospec2",
      :created_at => "2011-10-28T02:58:57Z",
      :drives => "--- \nephemeral1: \n  :type: :local\n  :size: 100\n  :index: 0\n",
      :uuid => "is-demospec2"
    }] + ORIGINAL_WAKAME_INSTANCE_SPECS

  ORIGINAL_WAKAME_HOST_NODES = [{
      :status => "online",
      :updated_at => "2011-10-18T03:53:24Z",
      :account_id => "a-shpoolxx",
      :offering_cpu_cores => 100,
      :offering_memory_size => 400000,
      :arch => "x86_64",
      :hypervisor => "kvm",
      :created_at => "2011-10-18T03:53:24Z",
      :name => "demohost",
      :uuid => "hp-demohost",
      :id => "hp-demohost"
    }]
  UPDATE_WAKAME_HOST_NODES = [{
      :status => "online",
      :updated_at => "2011-10-18T03:53:24Z",
      :account_id => "a-shpoolxx",
      :offering_cpu_cores => 75,
      :offering_memory_size => 350000,
      :arch => "x86_64",
      :hypervisor => "kvm",
      :created_at => "2011-10-18T03:53:24Z",
      :name => "demohost",
      :uuid => "hp-demohost",
      :id => "hp-demohost"
    }]
  CREATE_WAKAME_HOST_NODES = [{
      :status => "online",
      :updated_at => "2011-10-18T03:53:24Z",
      :account_id => "a-shpoolxx",
      :offering_cpu_cores => 75,
      :offering_memory_size => 350000,
      :arch => "x86_64",
      :hypervisor => "kvm",
      :created_at => "2011-10-18T03:53:24Z",
      :name => "demohost2",
      :uuid => "hp-demohost2",
      :id => "hp-demohost2"
    }] + ORIGINAL_WAKAME_HOST_NODES

  ORIGINAL_WAKAME_INSTANCES = [{
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
      #:aws_groups => nil,
      :spot_instance_request_id => "",
      #:ssh_key_name => nil,
      :virtualization_type => "",
      :placement_group_name => "",
      :requester_id => "",
      :aws_instance_id => "i-jria301q",
      :aws_product_codes => [],
      :client_token => "",
      :private_ip_address => ["192.168.2.188"],
      :architecture => "x86_64",
      :aws_state_code => 0,
      :aws_image_id => "wmi-lucid5",
      :root_device_type => "",
      :ip_address => {
        "nw-data" => ["192.168.2.188"],
        "nw-outside" => ["172.16.0.234"]
      },
      :dns_name => {
        "nw-data" => "jria301q.shpoolxx.vdc.local",
        "nw-outside" => "jria301q.shpoolxx.vdc.public"
      },
      :monitoring_state => "",
      :aws_instance_type => "is-demospec",
      :aws_state => "running",
      :private_dns_name => "jria301q.shpoolxx.vdc.local",
      :aws_reason => ""
    }]
  UPDATE_WAKAME_INSTANCES = [{
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
      #:aws_groups => nil,
      :spot_instance_request_id => "",
      #:ssh_key_name => nil,
      :virtualization_type => "",
      :placement_group_name => "",
      :requester_id => "",
      :aws_instance_id => "i-jria301q",
      :aws_product_codes => [],
      :client_token => "",
      :private_ip_address => ["192.168.2.188"],
      :architecture => "x86_64",
      :aws_state_code => 1,
      :aws_image_id => "wmi-lucid5",
      :root_device_type => "",
      :ip_address => {
        "nw-data" => ["192.168.2.188"],
        "nw-outside" => ["172.16.0.234"]
      },
      :dns_name => {
        "nw-data" => "jria301q.shpoolxx.vdc.local",
        "nw-outside" => "jria301q.shpoolxx.vdc.public"
      },
      :monitoring_state => "",
      :aws_instance_type => "is-demospec",
      :aws_state => "terminated",
      :private_dns_name => "jria301q.shpoolxx.vdc.local",
      :aws_reason => ""
    }]
  CREATE_WAKAME_INSTANCES = [{
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
      #:aws_groups => nil,
      :spot_instance_request_id => "",
      #:ssh_key_name => nil,
      :virtualization_type => "",
      :placement_group_name => "",
      :requester_id => "",
      :aws_instance_id => "i-jria302q",
      :aws_product_codes => [],
      :client_token => "",
      :private_ip_address => ["192.168.2.189"],
      :architecture => "x86_64",
      :aws_state_code => 0,
      :aws_image_id => "wmi-lucid5",
      :root_device_type => "",
      :ip_address => {
        "nw-data" => ["192.168.2.189"],
        "nw-outside" => ["172.16.0.235"]
      },
      :dns_name => {
        "nw-data" => "jria302q.shpoolxx.vdc.local",
        "nw-outside" => "jria302q.shpoolxx.vdc.public"
      },
      :monitoring_state => "",
      :aws_instance_type => "is-demospec",
      :aws_state => "running",
      :private_dns_name => "jria302q.shpoolxx.vdc.local",
      :aws_reason => ""
    }] + ORIGINAL_WAKAME_INSTANCES

  ORIGINAL_WAKAME_IMAGES = [{
      :root_device_name => "",
      :aws_ramdisk_id => "",
      :block_device_mappings => [{
          :ebs_snapshot_id => "",
          :ebs_volume_size => 0,
          :ebs_delete_on_termination => false,
          :device_name => ""
        }],
      :aws_is_public => false,
      :virtualization_type => "",
      :image_owner_alias => "",
      :aws_id => "wmi-lucid6",
      :aws_architecture => "x86",
      :root_device_type => "",
      :aws_location => "--- \n:snapshot_id: snap-lucid6\n",
      :aws_image_type => "",
      :name => "",
      :aws_state => "init",
      :description => "ubuntu-10.04_with-metadata_kvm_i386.raw volume",
      :aws_kernel_id => "",
      :tags => {},
      :aws_owner => "a-shpoolxx"
    }]
  UPDATE_WAKAME_IMAGES = [{
      :root_device_name => "",
      :aws_ramdisk_id => "",
      :block_device_mappings => [{
          :ebs_snapshot_id => "",
          :ebs_volume_size => 0,
          :ebs_delete_on_termination => false,
          :device_name => ""
        }],
      :aws_is_public => true,
      :virtualization_type => "",
      :image_owner_alias => "",
      :aws_id => "wmi-lucid6",
      :aws_architecture => "x86",
      :root_device_type => "",
      :aws_location => "--- \n:snapshot_id: snap-lucid6\n",
      :aws_image_type => "",
      :name => "",
      :aws_state => "init",
      :description => "ubuntu-10.04_with-metadata_kvm_i386.raw",
      :aws_kernel_id => "",
      :tags => {},
      :aws_owner => "a-shpoolxx"
    }]
  CREATE_WAKAME_IMAGES = [{
      :root_device_name => "",
      :aws_ramdisk_id => "",
      :block_device_mappings => [{
          :ebs_snapshot_id => "",
          :ebs_volume_size => 0,
          :ebs_delete_on_termination => false,
          :device_name => ""
        }],
      :aws_is_public => false,
      :virtualization_type => "",
      :image_owner_alias => "",
      :aws_id => "wmi-lucid7",
      :aws_architecture => "x86",
      :root_device_type => "",
      :aws_location => "--- \n:snapshot_id: snap-lucid7\n",
      :aws_image_type => "",
      :name => "",
      :aws_state => "init",
      :description => "ubuntu-10.04_with-metadata_kvm_i386.raw volume",
      :aws_kernel_id => "",
      :tags => {},
      :aws_owner => "a-shpoolxx"
    }] + ORIGINAL_WAKAME_IMAGES

end