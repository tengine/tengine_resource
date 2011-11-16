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
      providers = Tengine::Resource::Provider::Wakame.all
      providers.each do |provider|
        # APIからの仮想サーバタイプ情報を取得
        instance_specs = provider.instance_specs_from_api

        create_instance_specs = []
        update_instance_specs = []
        destroy_server_types = []

        # 仮想イメージタイプの取得
        old_server_types = provider.virtual_server_types
        old_server_types.each do |old_server_type|
          instance_spec = instance_specs.detect { |instance_spec| instance_spec[:id] == old_server_type.provided_id }
          instance_spec = instance_spec.symbolize_keys if instance_spec

          if instance_spec
            # APIで取得したサーバタイプと一致する且つ更新対象の差分があれば更新対象
            update_instance_specs << instance_spec if needs_to_update_server_type?(old_server_type, instance_spec)
          else
            # APIで取得したサーバタイプと一致するものがなければ削除対象
            destroy_server_types << old_server_type
          end
        end
        # APIで取得したサーバタイプがTengine上に存在しないものであれば登録対象
        create_instance_specs = instance_specs - update_instance_specs

        puts
        puts " >> target_instance_specs" * 5
        puts "    >> update_instance_specs"
        puts update_instance_specs.inspect
        puts "    >> create_instance_specs"
        puts create_instance_specs.inspect
        puts "    >> destroy_server_types"
        puts destroy_server_types.inspect

        # 更新
        provider.update_virtual_server_type_hashs(update_instance_specs) unless update_instance_specs.empty?
        # 登録
        provider.create_virtual_server_type_hashs(create_instance_specs) unless create_instance_specs.empty?
        # 削除
        destroy_server_types.each { |target| target.destroy }
      end
    end
  end

  private

  def needs_to_update_server_type?(old_server_type, instance_spec_hash)
    return false unless instance_spec_hash
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
    instance_spec = instance_spec_hash.dup
    changed_flag = false
    changed_flag = changed_flag || old_server_type.provided_id == instance_spec.delete(:id)
    changed_flag = changed_flag || old_server_type.caption == instance_spec.delete(:uuid)
    changed_flag = changed_flag || old_server_type.cpu_cores == instance_spec.delete(:cpu_cores)
    changed_flag = changed_flag || old_server_type.memory_size == instance_spec.delete(:memory_size)
    changed_flag = changed_flag || old_server_type.properties == instance_spec
    return changed_flag
  end

  extend Tengine::Core::MethodTraceable
  method_trace(*instance_methods(false))

end
