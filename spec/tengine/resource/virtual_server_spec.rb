# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Resource::VirtualServer do

  before(:all) do
    @fixture = GokuAtEc2ApNortheast.new
  end

  context "サーバの状態が変わったとき" do
    before do
      @fixture.virtual_servers
    end

    it "railsサーバが落とされたことを検出したのでサーバに反映できる" do
      rails1 = @fixture.rails_server(1)
      rails1.status = "terminated"
      rails1.save!
    end
  end


  context "nameで検索" do
    before do
      Tengine::Resource::Server.delete_all
      @fixture = GokuAtEc2ApNortheast.new
      @physical1 = @fixture.availability_zone(1)
      @virtual1 = @fixture.hadoop_master_node
      @virtual2 = @fixture.hadoop_slave_node(1)
    end

    context "見つかる場合" do
      it "find_by_name" do
        found_credential = nil
        lambda{
          found_credential = Tengine::Resource::VirtualServer.find_by_name(@virtual1.name)
        }.should_not raise_error
        found_credential.should_not be_nil
        found_credential.id.should == @virtual1.id
      end

      it "find_by_name!" do
        found_credential = nil
        lambda{
          found_credential = Tengine::Resource::VirtualServer.find_by_name!(@virtual2.name)
        }.should_not raise_error
        found_credential.should_not be_nil
        found_credential.id.should == @virtual2.id
      end
    end

    context "見つからない場合" do
      it "find_by_name" do
        found_credential = Tengine::Resource::VirtualServer.find_by_name(@physical1).should == nil
      end

      it "find_by_name!" do
        lambda{
          found_credential = Tengine::Resource::VirtualServer.find_by_name!(@physical1)
        }.should raise_error(Tengine::Core::FindByName::Error)
      end
    end

  end

end
