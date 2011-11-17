# -*- coding: utf-8 -*-
class Tengine::Resource::Provider::Wakame < Tengine::Resource::Provider::Ec2

  PHYSICAL_SERVER_STATES = [:online, :offline].freeze

  VIRTUAL_SERVER_STATES = [
    :scheduling, :pending, :starting, :running,
    :failingover, :shuttingdown, :terminated].freeze

  def update_virtual_server_images
    connect do |conn|
      hashs = conn.describe_images.map do |hash|
        {
          :provided_id => hash.delete(:aws_id),
          :provided_description => hash.delete(:aws_description),
        }
      end
      update_virtual_server_images_by(hashs)
    end
  end

  # @param  [String]                                 name         Name template for created virtual servers
  # @param  [Tengine::Resource::VirtualServerImage]  image        virtual server image object
  # @param  [Tengine::Resource::VirtualServerType]   type         virtual server type object
  # @param  [Tengine::Resource::PhysicalServer]      physical     physical server object
  # @param  [String]                                 description  what this virtual server is
  # @param  [Numeric]                                count        number of vortial servers to boot
  # @return [Array<Tengine::Resource::VirtualServer>]
  def create_virtual_servers name, image, type, physical, description = "", count = 1
    return super(
      name,
      image,
      type,
      physical.provided_id,
      description,
      count,  # min
      count,  # max
      [],     # grouop id
      self.properties[:key_name],
      "",     # user data
      nil,    # kernel id
      nil     # ramdisk id
    )
  end

  def terminate_virtual_servers servers
    connect do |conn|
      conn.terminate_instances(servers.map {|i| i.provided_id }).map do |hash|
        serv = self.virtual_servers.where(:provided_id => hash[:aws_instance_id]).first
        serv.update_attributes(:status => "shutdown in progress") if serv # <- ?
        serv
      end
    end
  end

  def capacities
    server_type_ids = virtual_server_types.map(&:provided_id)
    server_type_to_cpu = virtual_server_types.inject({}) do |d, server_type|
      d[server_type.provided_id] = server_type.cpu_cores
      d
    end
    server_type_to_mem = virtual_server_types.inject({}) do |d, server_type|
      d[server_type.provided_id] = server_type.memory_size
      d
    end
    physical_servers.inject({}) do |result, physical_server|
      if physical_server.status == 'online'
        cpu_free = physical_server.cpu_cores - physical_server.guest_servers.map{|s| server_type_to_cpu[s.provided_type_id]}.sum
        mem_free = physical_server.memory_size - physical_server.guest_servers.map{|s| server_type_to_mem[s.provided_type_id]}.sum
        result[physical_server.provided_id] = server_type_ids.inject({}) do |dest, server_type_id|
          dest[server_type_id] = [
            cpu_free / server_type_to_cpu[server_type_id],
            mem_free / server_type_to_mem[server_type_id]
          ].min
          dest
        end
      else
        result[physical_server.provided_id] = server_type_ids.inject({}) do |dest, server_type_id|
          dest[server_type_id] = 0; dest
        end
      end
      result
    end
  end

  private

  def address_order
    @@address_order ||= ['private_ip_address'.freeze].freeze
  end

  def connect
    h = [
      :account, 
      :ec2_host, :ec2_port, :ec2_protocol,
      :wakame_host, :wakame_port, :wakame_protocol,
    ].inject({}) {|r, i|
      r.update i => self.connection_settings[i]
    }
    connection = ::Tama::Controllers::ControllerFactory.create_controller(
      h[:account],
      h[:ec2_host],
      h[:ec2_port],
      h[:ec2_protocol],
      h[:wakame_host],
      h[:wakame_port],
      h[:wakame_protocol],
    )
    yield connection
  end
end
