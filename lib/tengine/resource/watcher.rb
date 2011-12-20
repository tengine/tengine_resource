# -*- coding: utf-8 -*-
require 'daemons'
require 'mongoid'
require 'eventmachine'
require 'tengine/event'
require 'tengine/mq'
require 'tengine/resource/config'

class Tengine::Resource::Watcher

  attr_reader :config, :pid

  def initialize(argv = [])
    @config = Tengine::Resource::Config::Resource.parse(argv)
    @pid = sprintf("process:%s/%d", ENV["MM_SERVER_NAME"], Process.pid)
    @mq_config = config[:event_queue].to_hash
    @mq_config[:sender] = { :keep_connection => true }
    @daemonize_options = {
      :app_name => 'tengine_resource_watchd',
      :ARGV => [config[:action]],
      :ontop => !config[:process][:daemon],
      # :monitor => true,
      :multiple => true,
      :dir_mode => :normal,
      :dir => File.expand_path(config[:process][:pid_dir]),
    }

    # 必要なディレクトリの生成
    FileUtils.mkdir_p(File.expand_path(config[:process][:pid_dir]))

    Tengine::Core::MethodTraceable.disabled = !config[:verbose]
  rescue Exception
    puts "[#{$!.class.name}] #{$!.message}\n  " << $!.backtrace.join("\n  ")
    raise
  end

  def mq_suite
    @mq_suite ||= Tengine::Mq::Suite.new(@mq_config)
    Tengine::Event.mq_suite = @mq_suite
  end

  def sender
    @sender ||= Tengine::Event::Sender.new(mq_suite)
    Tengine::Event.default_sender = @sender
  end

  def send_last_event
    sender.fire "finished.process.resourcew.tengine", :key => @uuid, :source_name => @pid, :sender_name => @pid, :occurred_at => Time.now, :level_key => :info, :keep_connection => true
    sender.stop
  end

  def send_periodic_event
    sender.fire "resourcew.heartbeat.tengine", :key => @uuid, :source_name => @pid, :sender_name => @pid, :occurred_at => Time.now, :level_key => :debug, :keep_connection => true, :retry_count => 0
  end

  def run(__file__)
    case config[:action].to_sym
    when :start
      start_daemon(__file__)
    when :stop
      stop_daemon(__file__)
    when :restart
      stop_daemon(__file__)
      start_daemon(__file__)
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
    @config.setup_loggers
    # observerの登録
    Mongoid.observers = Tengine::Resource::Observer
    Mongoid.instantiate_observers

    Mongoid.config.from_hash(config[:db])
    Mongoid.config.option(:persist_in_safe_mode, :default => true)

    EM.run do
      sender.wait_for_connection do
        providers = Tengine::Resource::Provider.all
        providers.each do |provider|
          provider.retry_on_error = true if provider.respond_to?(:retry_on_error=)
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
        ##############
        ## heartbeat
        int = @config[:heartbeat][:rwd][:interval].to_i
        if int and int > 0
          @periodic = EM.add_periodic_timer int do
            send_periodic_event
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
