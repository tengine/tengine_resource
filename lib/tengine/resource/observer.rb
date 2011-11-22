# -*- coding: utf-8 -*-
require 'mongoid'

require 'yaml'
require 'tengine_event'
require 'tengine/support/yaml_with_erb'

# http://mongoid.org/docs/callbacks/observers.html
class Tengine::Resource::Observer < Mongoid::Observer
  include Tengine::Event::ModelNotifiable

  class << self
    attr_accessor :disabled
    def silent_if_disabled
      return if self.disabled
      yield
    end
  end


  prefix = "tengine/resource/"
  observe *%w[physical_server virtual_server virtual_server_image virtual_server_type].map{|name| :"#{prefix}#{name}" }

  def event_sender
    @event_sender = Tengine::Event.default_sender
  end

  SUFFIX = "tengine_resource_watchd".freeze

  def event_type_name_suffix
    SUFFIX
  end

  private
  def fire_event(*args)
    # Mongoid::Observer#add_observer!でActiveModelとは別にdefine_callbacksメソッドでコールバックを定義しているので、
    # Mongoid.observers.disable(Tengine::Resource::Observer) を行ってもafter_createなどから呼び出されてしまう。
    # なので、呼び出された側でdisalbedフラグが立っていたら無視するようにしました。本来はmongoidだけでなんとかするべきかと思うので、
    # もしsilent_if_disabledとdisabledを削除しても正しく振る舞うならば削除するべきです。
    self.class.silent_if_disabled do
      Mongoid.observers.disabled_for?(self.class)
      super
    end
  end

end
