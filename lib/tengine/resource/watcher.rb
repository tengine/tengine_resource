# -*- coding: utf-8 -*-
require 'eventmachine'
require 'mongoid'
require 'apis/wakame'
require 'tengine/core/config'

class Tengine::Resource::Watcher

  attr_reader :config, :pid

  def initialize(argv = [])
    @config = Tengine::Core::Config.parse(argv)
    @pid = sprintf("process:%s/%d", ENV["MM_SERVER_NAME"], Process.pid)
    @daemonize_options = {
      :app_name => 'tengine_resource_watchd',
      :ARGV => ['start'],
      :ontop => !@config[:tengined][:daemon],
      :monitor => !@config[:tengined][:monitor],
      :multiple => true,
      :dir_mode => :normal,
      :dir => File.expand_path(@config[:tengined][:pid_dir]),
    }
    @daemonize_options.update(:ARGV => ['start'])
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
      # Wakameのプロバイダを対象として取得
      providers = Provider::Wakame.all
      providers.each do |provider|
        # APIからの仮想サーバタイプ情報を取得
        instance_specs = []
        provider.connection do |conn|
          instance_specs = JSON.parse(conn.show_instance_specs([]))
        end

        exists_instance_specs = []
        create_server_types = []
        update_server_types = []
        destroy_server_types = []

        # 仮想イメージタイプの取得
        old_server_types = provider.virtual_server_types
        old_server_types.each do |old_server_type|
          instance_spec = instance_specs.detect { |instance_spec| instance_spec["id"] == old_server_type.provided_id }

          if instance_spec
            # Tengine上に存在するサーバタイプを保持
            exists_instance_specs << instance_spec

            # APIで取得したサーバタイプと一致するものがあれば更新対象
            # さらに更新対象は差分があるかの比較
            update_server_type = needs_to_update_server_type(old_server_type, instance_spec)
            updata_server_types << update_server_type if update_server_type
          else
            # APIで取得したサーバタイプと一致するものがなければ削除対象
            destroy_server_types << old_server_type
          end
        end
        # APIで取得したサーバタイプがTengine上に存在しないものであれば登録対象
        create_server_types = instance_specs - exists_instance_specs
        create_server_types.map(:ServerType.convert)

        # 更新
        provider.update_virtual_server_types(update_server_types) unless update_server_types.empty?
        # 登録
        provider.create_virtual_server_types(create_server_types) unless create_server_types.empty?
        # 削除
        provicer.destroy_virtual_server_types(destroy_server_types) unless destroy_server_types.empty?
      end
    end
  end

  extend Tengine::Core::MethodTraceable
  method_trace(*instance_methods(false))

  private

  def needs_to_update_server_type(old_server_type, instance_spec)
    return nil unless instance_spec

    old_server_type.provided_id = instance_spec.delete("id")
    old_server_type.caption = instance_spec.delete("uuid")
    old_server_type.cpu_cores = instance_spec.delete("cpu_cores")
    old_server_type.memory_sites = instance_spec.delete("memory_size")
    old_server_type.properties.update(instance_spec)
    # :id
    # :uuid
    # :account_id
    # :cpu_cores
    # :memory_size
    # :arch
    # :hypervisor
    # :drives
    # :vifs
    # :quota_weight
    # :created_at
    # :updated_at
    return old_server_type if old_server_type.changed?
  end

end
