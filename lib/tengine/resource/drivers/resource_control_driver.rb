# -*- coding: utf-8 -*-

# リソース制御ドライバ
driver :resource_control_driver do

  on :'仮想サーバ起動リクエストイベント' do
    pid = event.properties.delete(:provider_id)
    if pid
      provider = Tengine::Resource::Provider.find(pid)
      if provider
        provider = provider.become provider._type
        provider.create_virtual_servers event.properties
      end
    end
  end

  on :'仮想サーバ停止リクエストイベント' do
    pid = event.properties.delete(:provider_id)
    if pid
      provider = Tengine::Resource::Provider.find(pid)
      if provider
        provider = provider.become provider._type
        provider.terminate_virtual_servers event.properties[:virtual_servers]
      end
    end
  end

  on :'Tengine::Resource::VirtualServer.created.tengine_resource_watchd'        # 仮想サーバ登録通知イベント
  on :'Tengine::Resource::VirtualServer.updated.tengine_resource_watchd'        # 仮想サーバ変更通知イベント
  on :'Tengine::Resource::VirtualServer.destroyed.tengine_resource_watchd'      # 仮想サーバ削除通知イベント
  on :'Tengine::Resource::PhysicalServer.created.tengine_resource_watchd'       # 物理サーバ登録通知イベント
  on :'Tengine::Resource::PhysicalServer.updated.tengine_resource_watchd'       # 物理サーバ変更通知イベント
  on :'Tengine::Resource::PhysicalServer.destroyed.tengine_resource_watchd'     # 物理サーバ削除通知イベント
  on :'Tengine::Resource::VirtualServerImage.created.tengine_resource_watchd'   # 仮想サーバイメージ登録通知イベント
  on :'Tengine::Resource::VirtualServerImage.updated.tengine_resource_watchd'   # 仮想サーバイメージ変更通知イベント
  on :'Tengine::Resource::VirtualServerImage.destroyed.tengine_resource_watchd' # 仮想サーバイメージ削除通知イベント
  on :'Tengine::Resource::VirtualServerType.created.tengine_resource_watchd'    # 仮想サーバタイプ登録通知イベント
  on :'Tengine::Resource::VirtualServerType.updated.tengine_resource_watchd'    # 仮想サーバタイプ変更通知イベント
  on :'Tengine::Resource::VirtualServerType.destroyed.tengine_resource_watchd'  # 仮想サーバタイプ削除通知イベント
end
