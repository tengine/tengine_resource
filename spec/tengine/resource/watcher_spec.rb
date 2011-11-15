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

  describe :start do

    before do
      @watcher = Tengine::Resource::Watcher.new
      EM.should_receive(:run).and_yield
    end

    it "初期処理が呼び出される" do
      @watcher.should_receive(:init_process)
      @watcher.start
    end

    describe :init_process do

      before do
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

      describe :sender do

        it "生成したmq_suiteが設定されている" do
          mock_mq = Tengine::Mq::Suite.new(@watcher.config[:event_queue])
          Tengine::Mq::Suite.should_receive(:new).
            with(@watcher.config[:event_queue]).and_return(mock_mq)

          @watcher.sender.should_receive(:wait_for_connection)
          @watcher.start
          @watcher.mq_suite.should == mock_mq
        end

        it "生成したsenderが設定されている", :failure => true do
          mock_mq = Tengine::Mq::Suite.new(@watcher.config[:event_queue])
          Tengine::Mq::Suite.should_receive(:new).
            with(@watcher.config[:event_queue]).and_return(mock_mq)

          mock_sender = mock(:sender)
          Tengine::Event::Sender.should_receive(:new).with(mock_mq).and_return(mock_sender)

          @watcher.sender.should_receive(:wait_for_connection)
          @watcher.start
          @watcher.sender.should == mock_sender
        end

        context "wakame" do
          before do
            Tengine::Resource::Provider.delete_all
#             @provider_ec2 = Tengine::Resource::Provider::Ec2.create!({
#                 :name => "amazon-ec2",
#                 :description => "",
#                 :properties => {
#                 },
#                 :polling_interval => 30,
#                 :connection_settings => {
#                   :access_key => "",
#                   :secret_access_key => "",
#                   :options => {
#                     :server => "ec2.amazonaws.com",
#                     :port => 443,
#                     :protocol => "https",
#                     :multi_thread => false,
#                     :logger => nil,
#                     :signature_version => '1',
#                     :cache => false,
#                   }
#                 }
#               })
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
            @virtual_server_type_wakame = @provider_wakame.create_virtual_server_type({
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

            @mock_mq = Tengine::Mq::Suite.new(@watcher.config[:event_queue])
            Tengine::Mq::Suite.should_receive(:new).
              with(@watcher.config[:event_queue]).and_return(@mock_mq)
            Tengine::Event.should_receive(:mq_suite).and_return(@mock_mq)
            Tengine::Event.should_receive(:default_sender).
              and_return(Tengine::Event::Sender.new(@mock_mq))
            Tengine::Event::Sender.should_receive(:new).with(@mock_mq)

            @tama_controller_factory = mock(::Tama::Controllers::ControllerFactory.allocate)
            ::Tama::Controllers::ControllerFactory.
              stub(:create_controller).
              with("test", nil, nil, nil, "192.168.0.10", 80, "http").
              and_return(@tama_controller_factory)
          end

          it "apiから仮想サーバタイプの情報が取得できる", :api => true do
            @watcher.sender.should_receive(:wait_for_connection).and_yield
#             api_conn = mock(:tama)
#             api_conn.should_receive(:show_instance_specs).with([]).
#               and_return(RESULT_UPDATE_WAKAME_SHOW_INSTANCE_SPECS)
#             @provider_wakame.should_receive(:connect).and_yield(api_conn)
            @tama_controller_factory.
              should_receive(:show_instance_specs).with([]).
              and_return(RESULT_UPDATE_WAKAME_SHOW_INSTANCE_SPECS)
            @watcher.start

          end

          it "更新対象あったら更新完了後イベントを発火する" do
            @watcher.sender.should_receive(:wait_for_connection).and_yield

            api_conn = mock(:tama)
            api_conn.should_receive(:show_instance_specs).with([]).
              and_return(RESULT_UPDATE_WAKAME_SHOW_INSTANCE_SPECS)
            @provider_wakame.should_receive(:connect).and_yield(api_conn)

            @virtual_server_type_wakame.update({
                :cpu_cores => 2,
                :memory_size => 512,
              })
            @provider_wakame.should_receive(:update_virtual_servers).
              with(@virtual_server_type_wakame)
            Tengine::Event.should_receive(:fire)
            mock_queue = mock(:queue)
            @mock_mq.should_receive(:queue).and_return(mock_queue)
            # mock_mq.should_receive(:wait_for_connection)

            @watcher.start
          end

          it "登録対象があったら登録完了後イベントを発火する" do
            @watcher.sender.should_receive(:wait_for_connection).and_yield

            api_conn = mock(:tama)
            api_conn.should_receive(:show_instance_specs).with([]).
              and_return(RESULT_CREATE_WAKAME_SHOW_INSTANCE_SPECS)
            @provider_wakame.should_receive(:connect).and_yield(api_conn)

            @provider_wakame.should_receive(:create_virtual_servers).
              with([{
                  :provided_id => "is-demospec2",
                  :caption => "is-demospec2",
                  :cpu_cores => 2,
                  :memory_size => 1024,
                  :properties => {
                    :arch => "x86_64",
                    :hypervisor => "kvm",
                    :account_id => "b-shpoolxx",
                    :vifs => "--- \neth0: \n  :bandwidth: 100000\n  :index: 0\n",
                    :quota_weight => "1.0",
                    :drives => "--- \nephemeral1: \n  :type: :local\n  :size: 100\n  :index: 0\n",
                    :created_at => "2011-10-28T02:58:57Z",
                    :updated_at => "2011-10-28T02:58:57Z",
                  }
                }]
              )
            Tengine::Event.should_receive(:fire)
            mock_queue = mock(:queue)
            @mock_mq.should_receive(:queue).and_return(mock_queue)
            # mock_mq.should_receive(:wait_for_connection)

            @watcher.start
          end

          it "削除対象があったら削除完了後イベントを発火する" do
            @watcher.sender.should_receive(:wait_for_connection).and_yield

            api_conn = mock(:tama)
            api_conn.should_receive(:show_instance_specs).with([]).and_return("")
            @provider_wakame.should_receive(:connect).and_yield(api_conn)

            @provider_wakame.should_receive(:destroy_virtual_servers).with(@virtual_server_type_wakame)
            Tengine::Event.should_receive(:fire)
            mock_queue = mock(:queue)
            @mock_mq.should_receive(:queue).and_return(mock_queue)
            # mock_mq.should_receive(:wait_for_connection)

            @watcher.start
          end

        end
      end
    end
  end


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
    }]

end
