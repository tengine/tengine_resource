# -*- coding: utf-8 -*-
require 'daemons'
require 'mongoid'
require 'eventmachine'
require 'tengine/event'
require 'tengine/mq'
require 'tengine/core/config'

class Tengine::Resource::Watcher

  attr_reader :config, :pid

  def initialize(argv = [])
    @config = Tengine::Core::Config.parse(argv)
    @config[:event_queue].update(
      :sender => {
        :keep_connection => true
      })
    @pid = sprintf("process:%s/%d", ENV["MM_SERVER_NAME"], Process.pid)
    @daemonize_options = {
      :app_name => 'tengine_resource_watchd',
      :ARGV => argv,
      :ontop => !@config[:tengined][:daemon],
      :monitor => !@config[:tengined][:monitor],
      :multiple => true,
      :dir_mode => :normal,
      :dir => File.expand_path(@config[:tengined][:pid_dir]),
    }
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

  def run(__file__)
    action = (@daemonize_options[:ARGV][0] || :start).to_sym

    case action
    when :start
      start_daemon(__file__)
    when :stop
      stop_daemon(__file__)
    when :restart
      stop_daemon(__file__)
      start_daemon(__file__)
    else
      puts "[#{$!.class.name}] invalid option: #{action}"
      raise
    end
  end

  def start_daemon(__file__)
    fname = File.basename __file__
    cwd = Dir.getwd
    Daemons.run_proc(fname, @daemonize_options) do
      Dir.chdir(cwd) { self.start }
    end
  end

  def stop_daemon(__file__)
    fname = File.basename __file__
    Daemons.run_proc(fname, @daemonize_options)
  end

  def start
    # observerの登録
    Mongoid.observers = Tengine::Resource::Observer
    Mongoid.instantiate_observers

    Mongoid.config.from_hash(@config[:db])
    Mongoid.config.option(:persist_in_safe_mode, :default => true)

    EM.run do
      sender.wait_for_connection do
        providers = Tengine::Resource::Provider.all
        providers.each do |provider|
          # 仮想サーバタイプの監視
          provider.virtual_server_type_watch
          @periodic = EM.add_periodic_timer(provider.polling_interval) do
            # 物理サーバの監視
            provider.physical_server_watch
            # 仮想サーバの監視
            provider.virtual_server_watch
            # 仮想サーバイメージの監視
            provider.virtual_server_image_watch
          end
        end
      end
    end
  end

  def shutdown
    EM.run do
      EM.cancel_timer @periodic if @periodic
      sender.stop
    end
  end

  extend Tengine::Core::MethodTraceable
  method_trace(*instance_methods(false))

end
