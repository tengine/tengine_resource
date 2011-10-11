# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "tengine_resource"
  s.version = "0.0.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["akima"]
  s.date = "2011-10-11"
  s.description = "tengine_resource provides physical/virtual server management"
  s.email = "akima@nautilus-technologies.com"
  s.executables = ["tengine_resource_watchd"]
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]
  s.files = [
    ".document",
    ".rspec",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "bin/tengine_resource_watchd",
    "lib/tengine/resource.rb",
    "lib/tengine/resource/credential.rb",
    "lib/tengine/resource/credential/ec2.rb",
    "lib/tengine/resource/credential/ec2/dummy.rb",
    "lib/tengine/resource/credential/ec2/launch_options.rb",
    "lib/tengine/resource/observer.rb",
    "lib/tengine/resource/physical_server.rb",
    "lib/tengine/resource/provider.rb",
    "lib/tengine/resource/provider/ec2.rb",
    "lib/tengine/resource/server.rb",
    "lib/tengine/resource/virtual_server.rb",
    "lib/tengine/resource/virtual_server_image.rb",
    "lib/tengine_resource.rb",
    "spec/fixtures/goku_at_ec2_ap_northeast.rb",
    "spec/mongoid.yml",
    "spec/spec_helper.rb",
    "spec/support/ec2.rb",
    "spec/tengine/resource/credential_spec.rb",
    "spec/tengine/resource/physical_server_spec.rb",
    "spec/tengine/resource/provider/ec2_spec.rb",
    "spec/tengine/resource/provider_spec.rb",
    "spec/tengine/resource/server_spec.rb",
    "spec/tengine/resource/virtual_server_image_spec.rb",
    "spec/tengine/resource/virtual_server_spec.rb",
    "spec/tengine_resource_spec.rb",
    "tengine_resource.gemspec"
  ]
  s.homepage = "http://github.com/akm/tengine_resource"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.10"
  s.summary = "tengine_resource provides physical/virtual server management"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<tengine_core>, ["~> 0.1.6"])
      s.add_runtime_dependency(%q<right_aws>, ["~> 2.1.0"])
      s.add_runtime_dependency(%q<net-ssh>, ["~> 2.2.1"])
      s.add_development_dependency(%q<rspec>, ["~> 2.6.0"])
      s.add_development_dependency(%q<factory_girl>, ["~> 2.1.2"])
      s.add_development_dependency(%q<yard>, ["~> 0.7.2"])
      s.add_development_dependency(%q<bundler>, ["~> 1.0.18"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.6.4"])
      s.add_development_dependency(%q<simplecov>, ["~> 0.5.3"])
      s.add_development_dependency(%q<ZenTest>, ["~> 4.6.2"])
    else
      s.add_dependency(%q<tengine_core>, ["~> 0.1.6"])
      s.add_dependency(%q<right_aws>, ["~> 2.1.0"])
      s.add_dependency(%q<net-ssh>, ["~> 2.2.1"])
      s.add_dependency(%q<rspec>, ["~> 2.6.0"])
      s.add_dependency(%q<factory_girl>, ["~> 2.1.2"])
      s.add_dependency(%q<yard>, ["~> 0.7.2"])
      s.add_dependency(%q<bundler>, ["~> 1.0.18"])
      s.add_dependency(%q<jeweler>, ["~> 1.6.4"])
      s.add_dependency(%q<simplecov>, ["~> 0.5.3"])
      s.add_dependency(%q<ZenTest>, ["~> 4.6.2"])
    end
  else
    s.add_dependency(%q<tengine_core>, ["~> 0.1.6"])
    s.add_dependency(%q<right_aws>, ["~> 2.1.0"])
    s.add_dependency(%q<net-ssh>, ["~> 2.2.1"])
    s.add_dependency(%q<rspec>, ["~> 2.6.0"])
    s.add_dependency(%q<factory_girl>, ["~> 2.1.2"])
    s.add_dependency(%q<yard>, ["~> 0.7.2"])
    s.add_dependency(%q<bundler>, ["~> 1.0.18"])
    s.add_dependency(%q<jeweler>, ["~> 1.6.4"])
    s.add_dependency(%q<simplecov>, ["~> 0.5.3"])
    s.add_dependency(%q<ZenTest>, ["~> 4.6.2"])
  end
end

