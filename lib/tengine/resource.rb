# -*- coding: utf-8 -*-
require 'tengine_resource'

module Tengine::Resource
  # モデル
  autoload :Server            , 'tengine/resource/server'
  autoload :PhysicalServer    , 'tengine/resource/physical_server'
  autoload :VirtualServer     , 'tengine/resource/virtual_server'
  autoload :VirtualServerImage, 'tengine/resource/virtual_server_image'
  autoload :VirtualServerType , 'tengine/resource/virtual_server_type'
  autoload :Credential        , 'tengine/resource/credential'
  autoload :Provider          , 'tengine/resource/provider'

  # モデルの更新を受けてイベントを発火するオブザーバ
  autoload :Observer          , 'tengine/resource/observer'
end
