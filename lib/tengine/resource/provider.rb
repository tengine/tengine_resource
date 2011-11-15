require 'mongoid'

class Tengine::Resource::Provider
  autoload :Ec2,    'tengine/resource/provider/ec2'
  autoload :Wakame, 'tengine/resource/provider/wakame'

  include Mongoid::Document
  include Mongoid::Timestamps
  include Tengine::Core::Validation
  include Tengine::Core::FindByName

  field :name, :type => String
  field :description, :type => String
  field :polling_interval, :type => Integer
  field :properties, :type => Hash

  validates :name, :presence => true, :uniqueness => true, :format => BASE_NAME.options
  index :name, :unique => true

  with_options(:inverse_of => :provider, :dependent => :destroy) do |c|
    c.has_many :physical_servers       , :class_name => "Tengine::Resource::PhysicalServer"
    c.has_many :virtual_servers        , :class_name => "Tengine::Resource::VirtualServer"
    c.has_many :virtual_server_images  , :class_name => "Tengine::Resource::VirtualServerImage"
    c.has_many :virtual_server_types   , :class_name => "Tengine::Resource::VirtualServerType"
  end

  def create_virtual_server_type(hash)
    properties = hash.dup
    puts "properties "*10
    puts properties
    self.virtual_server_types.create!(
      :provided_id => properties.delete(:id),
      :caption => properties.delete(:uuid),
      :cpu_cores => properties.delete(:cpu_cores),
      :memory_size => properties.delete(:memory_size),
      :properties => properties)
  end
  def create_virtual_server_types(hashs)
    created_ids = []
    hashs.each do |hash|
      server_type = create_virtual_server_type(hash)
      created_ids << server_type.id
    end
    created_ids
  end

  def update_virtual_server_type(hash)
    virtual_server_type = self.virtual_server_types.where(
      :provided_id => hash[:id]).first
    properties = hash.dup
    virtual_server_type.update_attributes(
      :provided_id => properties.delete(:id),
      :caption => properties.delete(:uuid),
      :cpu_cores => properties.delete(:cpu_cores),
      :memory_size => properties.delete(:memory_size),
      :properties => properties)
  end
  def update_virtual_server_types(hashs)
    updated_ids = []
    hashs.each do |hash|
      server_type = update_virtual_server_type(hash)
      updated_server_types << server_type
    end
    updated_server_types
  end

  def update_physical_servers      ; raise NotImplementedError end
  def update_virtual_servers       ; raise NotImplementedError end
  def update_virtual_server_imagess; raise NotImplementedError end

  private
  def update_physical_servers_by(hashs)
    found_ids = []
    hashs.each do |hash|
      server = self.physical_servers.where(:provided_id => hash[:provided_id]).first
      if server
        server.update_attributes(:status => hash[:status])
      else
        server = self.physical_servers.create!(
          :provided_id => hash[:provided_id],
          :name => hash[:name],
          :status => hash[:status])
      end
      found_ids << server.id
    end
    self.physical_servers.not_in(:_id => found_ids).update_all(:status => "not_found")
  end

  def update_virtual_servers_by(hashs)
    found_ids = []
    hashs.each do |hash|
      server = self.virtual_servers.where(:provided_id => hash[:provided_id]).first
      if server
        server.update_attributes(hash)
      else
        server = self.virtual_servers.create!(hash.merge(:name => hash[:provided_id]))
      end
      found_ids << server.id
    end
    self.virtual_servers.not_in(:_id => found_ids).destroy_all
  end

  class << self
    def find_or_create_by_name!(attrs)
      result = self.first(:conditions => {:name => attrs[:name]})
      result ||= self.create!(attrs)
      result
    end
  end
end
