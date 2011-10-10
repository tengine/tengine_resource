# -*- coding: utf-8 -*-
require 'mongoid'

class Tengine::Resource::Server
  include Mongoid::Document
  include Tengine::Core::CollectionAccessible
  include Tengine::Core::Validation

  field :name         , :type => String
  field :description  , :type => String
  field :provided_name, :type => String
  field :status       , :type => String

  field :public_hostname, :type => String
  field :public_ipv4    , :type => String
  field :local_hostname , :type => String
  field :local_ipv4     , :type => String
  field :properties     , :type => Hash
  map_yaml_accessor :properties

  validates :name, :presence => true, :uniqueness => true, :format => BASE_NAME.options

  has_many :guest, :class_name => "Tengine::Resource::VirtualServer", :inverse_of => :host

  class << self
    def find_or_create_by_name!(attrs = {}, &block)
      result = Tengine::Resource::Server.first(:conditions => {:name => attrs[:name]})
      result ||= self.create!(attrs)
      result
    end
  end
end
