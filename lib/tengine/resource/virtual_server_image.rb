require 'mongoid'

class Tengine::Resource::VirtualServerImage
  include Mongoid::Document
  include Tengine::Core::Validation

  field :name, :type => String
  field :description, :type => String
  field :provided_name, :type => String
  belongs_to :provider, :inverse_of => :virtual_server_images, :index => true,
    :class_name => "Tengine::Resource::Provider"

  validates :name, :presence => true, :uniqueness => true, :format => BASE_NAME.options

  class << self
    def find_or_create_by_name!(attrs = {}, &block)
      result = self.first(:conditions => {:name => attrs[:name]})
      result ||= self.create!(attrs)
      result
    end
  end
end
