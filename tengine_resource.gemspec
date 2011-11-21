# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "tengine_resource"
  s.version = "0.4.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["saishu", "w-irie", "taigou", "totty", "hiroshinakao", "g-morita", "guemon", "aoetk", "hattori-at-nt", "t-yamada", "y-karashima", "akm"]
  s.date = "2011-11-21"
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

