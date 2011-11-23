# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "tengine_resource"
  s.version = "0.4.12"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["saishu", "w-irie", "taigou", "totty", "hiroshinakao", "g-morita", "guemon", "aoetk", "hattori-at-nt", "t-yamada", "y-karashima", "akm"]
  s.date = "2011-11-23"
  s.description = "tengine_resource provides physical/virtual server management"
  s.email = "tengine@nautilus-technologies.com"
  s.executables = ["tengine_resource_watchd"]
  s.extra_rdoc_files = [
    "README.rdoc"
  ]
  s.files = [
    ".document",
    ".rspec",
    "Gemfile",
    "Gemfile.lock",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "bin/tengine_resource_watchd",
    "config/.gitignore",
    "config/watchd.yml.erb.example",
    "lib/tengine/resource.rb",
    "lib/tengine/resource/config.rb",
    "lib/tengine/resource/config/resource.rb",
    "lib/tengine/resource/credential.rb",
    "lib/tengine/resource/credential/ec2.rb",
    "lib/tengine/resource/credential/ec2/dummy.rb",
    "lib/tengine/resource/credential/ec2/launch_options.rb",
    "lib/tengine/resource/drivers/resource_control_driver.rb",
    "lib/tengine/resource/net_ssh.rb",
    "lib/tengine/resource/observer.rb",
    "lib/tengine/resource/physical_server.rb",
    "lib/tengine/resource/provider.rb",
    "lib/tengine/resource/provider/ec2.rb",
    "lib/tengine/resource/provider/wakame.rb",
    "lib/tengine/resource/server.rb",
    "lib/tengine/resource/virtual_server.rb",
    "lib/tengine/resource/virtual_server_image.rb",
    "lib/tengine/resource/virtual_server_type.rb",
    "lib/tengine/resource/watcher.rb",
    "lib/tengine_resource.rb",
    "spec/fixtures/goku_at_ec2_ap_northeast.rb",
    "spec/mongoid.yml",
    "spec/spec_helper.rb",
    "spec/support/ec2.rb",
    "spec/tengine/resource/credential_spec.rb",
    "spec/tengine/resource/drivers/resource_control_driver_spec.rb",
    "spec/tengine/resource/net_ssh_spec.rb",
    "spec/tengine/resource/physical_server_spec.rb",
    "spec/tengine/resource/provider/ec2_spec.rb",
    "spec/tengine/resource/provider/test_files/describe_host_nodes.json",
    "spec/tengine/resource/provider/test_files/describe_images.json",
    "spec/tengine/resource/provider/test_files/describe_instance_specs.json",
    "spec/tengine/resource/provider/test_files/describe_instances.json",
    "spec/tengine/resource/provider/test_files/run_instances.json",
    "spec/tengine/resource/provider/test_files/terminate_instances.json",
    "spec/tengine/resource/provider/wakame/00_describe_host_nodes_0_physical_servers.json",
    "spec/tengine/resource/provider/wakame/01_describe_host_nodes_10_physical_servers.json",
    "spec/tengine/resource/provider/wakame/02_describe_host_nodes_60_physical_servers.json",
    "spec/tengine/resource/provider/wakame/10_describe_instances_0_virtual_servers.json",
    "spec/tengine/resource/provider/wakame/11_describe_instances_10_virtual_servers.json",
    "spec/tengine/resource/provider/wakame/12_describe_instances_after_run_instances.json",
    "spec/tengine/resource/provider/wakame/13_describe_instances_after_terminate_instances.json",
    "spec/tengine/resource/provider/wakame/20_describe_images_0_virtual_server_images.json",
    "spec/tengine/resource/provider/wakame/21_describe_images_5_virtual_server_images.json",
    "spec/tengine/resource/provider/wakame/22_describe_images_60_virtual_server_images.json",
    "spec/tengine/resource/provider/wakame/30_describe_instance_specs_0_virtual_server_specs.json",
    "spec/tengine/resource/provider/wakame/31_describe_instance_specs_4_virtual_server_specs.json",
    "spec/tengine/resource/provider/wakame/40_run_instances_0_virtual_servers.json",
    "spec/tengine/resource/provider/wakame/41_run_instances_1_virtual_servers.json",
    "spec/tengine/resource/provider/wakame/42_run_instances_5_virtual_servers.json",
    "spec/tengine/resource/provider/wakame/50_terminate_instances_0_virtual_servers.json",
    "spec/tengine/resource/provider/wakame/51_terminate_instances_3_virtual_servers.json",
    "spec/tengine/resource/provider/wakame/sync_physical_servers_spec.rb",
    "spec/tengine/resource/provider/wakame/sync_virtual_server_images_spec.rb",
    "spec/tengine/resource/provider/wakame/sync_virtual_server_types_spec.rb",
    "spec/tengine/resource/provider/wakame/sync_virtual_servers_spec.rb",
    "spec/tengine/resource/provider/wakame_api_spec.rb",
    "spec/tengine/resource/provider/wakame_spec.rb",
    "spec/tengine/resource/provider_spec.rb",
    "spec/tengine/resource/server_spec.rb",
    "spec/tengine/resource/virtual_server_image_spec.rb",
    "spec/tengine/resource/virtual_server_spec.rb",
    "spec/tengine/resource/virtual_server_type_spec.rb",
    "spec/tengine/resource/watcher_spec.rb",
    "spec/tengine_resource_spec.rb",
    "tengine_resource.gemspec",
    "tmp/log/.gitignore"
  ]
  s.homepage = "http://github.com/tengine/tengine_resource"
  s.licenses = ["MPL/LGPL"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.10"
  s.summary = "tengine_resource provides physical/virtual server management"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<tengine_support>, ["~> 0.3.12"])
      s.add_runtime_dependency(%q<tengine_core>, ["~> 0.4.0"])
      s.add_runtime_dependency(%q<right_aws>, ["~> 2.1.0"])
      s.add_runtime_dependency(%q<net-ssh>, ["~> 2.2.1"])
      s.add_development_dependency(%q<rspec>, ["~> 2.6.0"])
      s.add_development_dependency(%q<factory_girl>, ["~> 2.1.2"])
      s.add_development_dependency(%q<yard>, ["~> 0.7.2"])
      s.add_development_dependency(%q<bundler>, ["~> 1.0.18"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.6.4"])
      s.add_development_dependency(%q<simplecov>, ["~> 0.5.3"])
      s.add_development_dependency(%q<ZenTest>, ["~> 4.6.2"])
      s.add_development_dependency(%q<wakame-adapters-tengine>, ["~> 0.0.0"])
    else
      s.add_dependency(%q<tengine_support>, ["~> 0.3.12"])
      s.add_dependency(%q<tengine_core>, ["~> 0.4.0"])
      s.add_dependency(%q<right_aws>, ["~> 2.1.0"])
      s.add_dependency(%q<net-ssh>, ["~> 2.2.1"])
      s.add_dependency(%q<rspec>, ["~> 2.6.0"])
      s.add_dependency(%q<factory_girl>, ["~> 2.1.2"])
      s.add_dependency(%q<yard>, ["~> 0.7.2"])
      s.add_dependency(%q<bundler>, ["~> 1.0.18"])
      s.add_dependency(%q<jeweler>, ["~> 1.6.4"])
      s.add_dependency(%q<simplecov>, ["~> 0.5.3"])
      s.add_dependency(%q<ZenTest>, ["~> 4.6.2"])
      s.add_dependency(%q<wakame-adapters-tengine>, ["~> 0.0.0"])
    end
  else
    s.add_dependency(%q<tengine_support>, ["~> 0.3.12"])
    s.add_dependency(%q<tengine_core>, ["~> 0.4.0"])
    s.add_dependency(%q<right_aws>, ["~> 2.1.0"])
    s.add_dependency(%q<net-ssh>, ["~> 2.2.1"])
    s.add_dependency(%q<rspec>, ["~> 2.6.0"])
    s.add_dependency(%q<factory_girl>, ["~> 2.1.2"])
    s.add_dependency(%q<yard>, ["~> 0.7.2"])
    s.add_dependency(%q<bundler>, ["~> 1.0.18"])
    s.add_dependency(%q<jeweler>, ["~> 1.6.4"])
    s.add_dependency(%q<simplecov>, ["~> 0.5.3"])
    s.add_dependency(%q<ZenTest>, ["~> 4.6.2"])
    s.add_dependency(%q<wakame-adapters-tengine>, ["~> 0.0.0"])
  end
end

