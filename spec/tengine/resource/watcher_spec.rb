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
          :polling_interval => 30,
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
          :polling_interval => 30,
          :connection_settings => {
            :account => "test",
            :host => "192.168.0.10",
            :port => 80,
            :protocol => "http",
            :private_network_data => "",
          },
        })
    end

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
          @tama_controller_factory = mock(::Tama::Controllers::ControllerFactory.allocate)
          ::Tama::Controllers::ControllerFactory.
            should_receive(:create_controller).
            with("test", nil, nil, nil, "192.168.0.10", 80, "http").
            and_return(@tama_controller_factory)
        end

        it "更新対象があったら更新完了後イベントを発火する" do
          @tama_controller_factory.
            should_receive(:show_instance_specs).with([]).
            and_return(RESULT_UPDATE_WAKAME_SHOW_INSTANCE_SPECS)

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
            and_return(ORIGINAL_WAKAME_SHOW_INSTANCE_SPECS)

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
            and_return(RESULT_CREATE_WAKAME_SHOW_INSTANCE_SPECS)

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
        it "実行されない" do
          Tengine::Resource::Provider.should_receive(:all).and_return([@provider_ec2])
          @provider_ec2.should_not_receive(:instance_specs_from_api)
          @watcher.start
        end
      end   # end to ec2
    end   # end to :virtual_server_type_watch

  end   # end to :start

  ORIGINAL_WAKAME_SHOW_INSTANCE_SPECS = [{
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

  RESULT_UPDATE_WAKAME_SHOW_INSTANCE_SPECS = [{
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

  RESULT_CREATE_WAKAME_SHOW_INSTANCE_SPECS = [{
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
    }] + ORIGINAL_WAKAME_SHOW_INSTANCE_SPECS

end
