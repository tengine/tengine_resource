# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Resource::Server do

  valid_attributes1 = {
    :name => "server1",
  }.freeze

  [Tengine::Resource::Server, Tengine::Resource::PhysicalServer, Tengine::Resource::VirtualServer].each do |klass|
    context "#{klass.name}#name は必須" do
      it "正常系" do
        klass.delete_all
        credential1 = klass.new(valid_attributes1)
        credential1.valid?.should == true
      end

      [:name].each do |key|
        it "#{key}なし" do
          attrs = valid_attributes1.dup
          attrs.delete(key)
          credential1 = klass.new(attrs)
          credential1.valid?.should == false
        end
      end

    end
  end

  context "nameはユニーク" do
    [Tengine::Resource::Server, Tengine::Resource::PhysicalServer, Tengine::Resource::VirtualServer].each do |klass|
      context "#{klass.name}#name はユニーク" do
        before do
          Tengine::Resource::Server.delete_all
          @credential1 = klass.create!(valid_attributes1)
        end

        it "同じ名前で登録されているものが存在する場合エラー" do
          expect{
            @credential1 = klass.create!(valid_attributes1)
          }.to raise_error(Mongoid::Errors::Validations, "Validation failed - Name is already taken.")
        end
      end
    end

    context "PhysicalServerかVirutalServerかは名前の一意性に関係ない" do
      before do
        Tengine::Resource::PhysicalServer.delete_all
        Tengine::Resource::VirtualServer.delete_all
      end

      it "同名のPhysicalServerが先にある場合" do
        name = "server1"
        Tengine::Resource::PhysicalServer.create!(:name => name)
        expect{
          Tengine::Resource::VirtualServer.create!(:name => name)
        }.to raise_error(Mongoid::Errors::Validations,
          "Validation failed - Name is already taken.")
      end

      it "同名のVirtualServerが先にある場合" do
        name = "server1"
        Tengine::Resource::VirtualServer.create!(:name => name)
        expect{
          Tengine::Resource::PhysicalServer.create!(:name => name)
        }.to raise_error(Mongoid::Errors::Validations,
          "Validation failed - Name is already taken.")
      end


    end
  end


end
