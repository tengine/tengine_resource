# -*- coding: utf-8 -*-
require 'spec_helper'
require 'eventmachine'
require 'amqp'
require 'tengine/mq/suite'

describe Tengine::Resource::Watcher do
  before do
  end

  context :initialize do
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

  context :start do
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

      it "生成したmq_suiteが設定されている" do
        mock_mq = Tengine::Mq::Suite.new(@watcher.config[:event_queue])
        Tengine::Mq::Suite.should_receive(:new).
          with(@watcher.config[:event_queue]).and_return(mock_mq)

        @watcher.sender.should_receive(:wait_for_connection)
        @watcher.start
      end

      it "生成したsenderが設定されている", :failure => true do
        mock_mq = Tengine::Mq::Suite.new(@watcher.config[:event_queue])
        Tengine::Mq::Suite.should_receive(:new).
          with(@watcher.config[:event_queue]).and_return(mock_mq)
        mock_sender = mock(:sender)
        Tengine::Event::Sender.should_receive(:new).with(mock_mq).and_return(mock_sender)

        @watcher.sender.should_receive(:wait_for_connection)
        @watcher.start
      end

    end
  end


end
