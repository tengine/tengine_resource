# -*- coding: utf-8 -*-
require 'spec_helper'
require 'eventmachine'
require 'amqp'
require 'tengine/mq/suite'
require 'apis/wakame'
require 'controllers/controller'

describe Tengine::Resource::Watcher do
  before do
  end

  after do
    @watcher = nil
  end

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
      AMQP.should_receive(:connect).with({
          :user=>"guest", :pass=>"guest", :vhost=>"/",
          :logging=>false, :insist=>false, :host=>"localhost", :port=>5672}).
        and_return(mock_conn)
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
      AMQP.should_receive(:connect).with({
          :user=>"guest", :pass=>"guest", :vhost=>"/",
          :logging=>false, :insist=>false, :host=>"localhost", :port=>5672}).
        and_return(mock_conn)
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
            should_receive(:show_instance_specs).with([]).
            and_return(RESULT_UPDATE_WAKAME_INSTANCE_SPECS)

          Tengine::Event.default_sender.should_receive(:fire).with(
            "Tengine::Resource::VirtualServerType.updated.tengine_resource_watchd",
            anything())

          @watcher.start

          @virtual_server_type_wakame.cpu_cores.should == 2
          @virtual_server_type_wakame.memory_size.should == 512

          @provider_wakame.reload
          new_server_type = @provider_wakame.virtual_server_types.first
          new_server_type.cpu_cores.should == 1
          new_server_type.memory_size.should == 256
        end

        it "更新対象がなかったらイベントは発火しない" do
          @tama_controller_factory.
            should_receive(:show_instance_specs).with([]).
            and_return(ORIGINAL_WAKAME_INSTANCE_SPECS)

          Tengine::Event.default_sender.should_not_receive(:fire)

          @watcher.start

          @virtual_server_type_wakame.cpu_cores.should == 2
          @virtual_server_type_wakame.memory_size.should == 512

          @provider_wakame.reload
          new_server_type = @provider_wakame.virtual_server_types.first
          new_server_type.cpu_cores.should == 2
          new_server_type.memory_size.should == 512
        end

        it "登録対象があったら登録完了後イベントを発火する" do
          @tama_controller_factory.
            should_receive(:show_instance_specs).with([]).
            and_return(RESULT_CREATE_WAKAME_INSTANCE_SPECS)

          Tengine::Event.default_sender.should_receive(:fire).with(
            "Tengine::Resource::VirtualServerType.created.tengine_resource_watchd",
            anything())

          expect { @watcher.start }.should change(
            @provider_wakame.virtual_server_types, :count).by(1)
        end

        it "削除対象があったら削除完了後イベントを発火する" do
          @tama_controller_factory.
            should_receive(:show_instance_specs).with([]).
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

          @tama_controller_factory = mock(::Tama::Controllers::ControllerFactory.allocate)
          ::Tama::Controllers::ControllerFactory.
            should_receive(:create_controller).
            with("test", nil, nil, nil, "192.168.0.10", 80, "http").
            and_return(@tama_controller_factory)
        end

        it "更新対象があったら更新完了後イベントを発火する" do
          @tama_controller_factory.
            should_receive(:show_host_nodes).and_return(RESULT_UPDATE_WAKAME_HOST_NODES)

          Tengine::Event.default_sender.should_receive(:fire).with(
            "Tengine::Resource::PhysicalServer.updated.tengine_resource_watchd",
            anything())

          @watcher.start

          @physical_server_wakame.cpu_cores.should == 100
          @physical_server_wakame.memory_size.should == 400000

          @provider_wakame.reload
          new_server = @provider_wakame.physical_servers.first
          new_server.cpu_cores.should == 75
          new_server.memory_size.should == 350000
        end

        it "更新対象がなかったらイベントは発火しない" do
          @tama_controller_factory.
            should_receive(:show_host_nodes).and_return(ORIGINAL_WAKAME_HOST_NODES)

          Tengine::Event.default_sender.should_not_receive(:fire)

          @watcher.start

          @physical_server_wakame.cpu_cores.should == 100
          @physical_server_wakame.memory_size.should == 400000

          @provider_wakame.reload
          new_server = @provider_wakame.physical_servers.first
          new_server.cpu_cores.should == 100
          new_server.memory_size.should == 400000
        end

        it "登録対象があったら登録完了後イベントを発火する" do
          @tama_controller_factory.
            should_receive(:show_host_nodes).and_return(RESULT_CREATE_WAKAME_HOST_NODES)

          Tengine::Event.default_sender.should_receive(:fire).with(
            "Tengine::Resource::PhysicalServer.created.tengine_resource_watchd",
            anything())

          expect { @watcher.start }.should change(
            @provider_wakame.physical_servers, :count).by(1)
        end

        it "削除対象があったら削除完了後イベントを発火する" do
          @tama_controller_factory.
            should_receive(:show_host_nodes).and_return([])

          Tengine::Event.default_sender.should_receive(:fire).with(
            "Tengine::Resource::PhysicalServer.destroyed.tengine_resource_watchd",
            anything())

          expect { @watcher.start }.should change(
            @provider_wakame.physical_servers, :size).by(-1)
        end
      end   # end to :wakame
    end   # end to :phyical_server_watch

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
  RESULT_UPDATE_WAKAME_INSTANCE_SPECS = [{
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
  RESULT_CREATE_WAKAME_INSTANCE_SPECS = [{
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
  RESULT_UPDATE_WAKAME_HOST_NODES = [{
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
  RESULT_CREATE_WAKAME_HOST_NODES = [{
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

  ORIGINAL_WAKAME_DESCRIBE_INSTANCES = [{
      :vif => [{
         :ipv4 => {
           :nat_address => "172.16.0.234",
           :address => "192.168.2.188"
         },
         :vif_id => "vif-aspojqs4"
       }],
      :status => "online",
      :memory_size => 256,
      :ha_enabled => 0,
      :network => [{
         :nat_ipaddr => ["172.16.0.234"],
         :nat_dns_name => "jria301q.shpoolxx.vdc.public",
         :dns_name => "jria301q.shpoolxx.vdc.local",
         :ipaddr => ["192.168.2.188"],
         :nat_network_name => "nw-outside",
         :network_name => "nw-data"
       }],
      :state => "running",
      :image_id => "wmi-lucid5",
      :arch => "x86_64",
      :hostname => "jria301q",
      :host_node => "hp-demohost",
      :created_at => "2011-10-18T06:51:16Z",
      :instance_spec_id => "is-demospec",
      :netfilter_group_id => ["ng-demofgr"],
      #:ssh_key_pair => null,
      :volume => [],
      :netfilter_group => ["default"],
      :id => "i-jria301q",
      :cpu_cores => 1
    },
    {
      :vif => [{
         :ipv4 => {
           #:nat_address => null,
           :address => "192.168.2.94"
         },
         :vif_id => "vif-h85j75s9"
       }],
      :status => "online",
      :memory_size => 256,
      :ha_enabled => 0,
      :network => [{
         :nat_ipaddr => [],
         #:nat_dns_name => null,
         :dns_name => "9pia8e7p.shpoolxx.vdc.local",
         :ipaddr => ["192.168.2.94"],
         #:nat_network_name => null,
         :network_name => "nw-data"
       }],
      :state => "running",
      :image_id => "wmi-lucid5",
      :arch => "x86_64",
      :hostname => "9pia8e7p",
      :host_node => "hp-demohost",
      :created_at => "2011-10-18T06:48:47Z",
      :instance_spec_id => "is-demospec",
      :netfilter_group_id => ["ng-demofgr"],
      #:ssh_key_pair => null,
      :volume => [],
      :netfilter_group => ["default"],
      :id => "i-9pia8e7p",
      :cpu_cores => 1
    }]
end
