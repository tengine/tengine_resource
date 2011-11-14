# -*- coding: utf-8 -*-
require 'eventmachine'
require 'mongoid'

require 'tengine/core/config'

class Tengine::Resource::Watcher

  attr_reader :config, :pid

  def initialize(argv = [])
    @config = Tengine::Core::Config.parse(argv)
    @pid = sprintf("process:%s/%d", ENV["MM_SERVER_NAME"], Process.pid)
    Tengine::Core::MethodTraceable.disabled = !@config[:verbose]
  rescue Exception
    puts "[#{$!.class.name}] #{$!.message}\n  " << $!.backtrace.join("\n  ")
    raise
  end

  def mq_suite
    @mq_suite ||= Tengine::Mq::Suite.new(config[:event_queue])
    Tengine::Event.mq_suite = @mq_suite
  end

  def sender
    @sender ||= Tengine::Event::Sender.new(mq_suite)
    Tengine::Event.default_sender = @sender
  end

  def start
    # observerの登録
    Mongoid.observers = Tengine::Resource::Observer
    Mongoid.instantiate_observers

    Mongoid.config.from_hash(@config[:db])
    Mongoid.config.option(:persist_in_safe_mode, :default => true)
    Mongoid::Document.module_eval do
      include Tengine::Core::CollectionAccessible
    end

    EM.run do
      init_process
    end
  end

  def init_process
    sender.wait_for_connection do
    end
  end

  extend Tengine::Core::MethodTraceable
  method_trace(*instance_methods(false))

end
