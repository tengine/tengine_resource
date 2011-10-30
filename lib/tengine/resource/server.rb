# -*- coding: utf-8 -*-
require 'mongoid'

class Tengine::Resource::Server
  include Mongoid::Document
  include Mongoid::Timestamps
  include Tengine::Core::CollectionAccessible
  include Tengine::Core::Validation

  field :name         , :type => String
  field :description  , :type => String
  field :provided_name, :type => String
  field :status       , :type => String

  # field :public_hostname, :type => String
  # field :public_ipv4    , :type => String
  # field :local_hostname , :type => String
  # field :local_ipv4     , :type => String

  field :addresses      , :type => Hash, :default => {}
  field :properties     , :type => Hash
  map_yaml_accessor :properties

  validates :name, :presence => true, :uniqueness => true, :format => BASE_NAME.options
  index :name, :unique => true

  has_many :guest, :class_name => "Tengine::Resource::VirtualServer", :inverse_of => :host

  class << self
    def find_or_create_by_name!(attrs = {}, &block)
      result = Tengine::Resource::Server.first(:conditions => {:name => attrs[:name]})
      result ||= self.create!(attrs)
      result
    end
  end

  def hostname_or_ipv4
    # local_ipv4 || local_hostname || public_ipv4 || public_hostname # nilだけでなく空文字列も考慮する必要があります
    [:local_ipv4, :local_hostname, :public_ipv4, :public_hostname].map{|attr| send(attr)}.detect{|s| !s.blank?}
  end

  def hostname_or_ipv4?
    !!hostname_or_ipv4
  end

  %w[public_hostname public_ipv4 local_hostname local_ipv4].each do |address_key|
    class_eval(<<-END_OF_METHOD, __FILE__, __LINE__ + 1)
      def #{address_key}
        addresses['#{address_key}']
      end
      def #{address_key}=(value)
        addresses['#{address_key}'] = value
      end
    END_OF_METHOD
  end

end
