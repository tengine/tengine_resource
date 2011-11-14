class Tengine::Resource::VirtualServer < Tengine::Resource::Server
  field :provided_image_id, :type => String
  field :provided_type_id, :type => String

  belongs_to :host_server, :inverse_of => :guest_servers, :index => true,
    :class_name => "Tengine::Resource::Server"
  belongs_to :provider, :index => true, :inverse_of => :virtual_servers,
    :class_name => "Tengine::Resource::Provider"
end
