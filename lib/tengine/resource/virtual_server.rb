class Tengine::Resource::VirtualServer < Tengine::Resource::Server
  field :provided_image_id, :type => String
  field :provided_type_id, :type => String

  belongs_to :host_server, :inverse_of => :guest_servers, :index => true,
    :class_name => "Tengine::Resource::Server"
  belongs_to :provider, :index => true, :inverse_of => :virtual_servers,
    :class_name => "Tengine::Resource::Provider"

  validates_uniqueness_of :provided_id, :scope => :provider_id
  index [[:provided_id,  Mongo::ASCENDING], [:provider_id,  Mongo::ASCENDING], ], :unique => true

end
