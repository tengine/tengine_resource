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

  context "nameはベース名として定義される文字列です" do
    it "スラッシュ'/’はリソース識別子で使われるのでnameには使用できません" do
      server1 = Tengine::Resource::Server.new(:name => "foo/bar")
      server1.valid?.should == false
      server1.errors[:name].should == [Tengine::Core::Validation::BASE_NAME.message]
    end

    it "コロン':'はリソース識別子で使われるのでnameには使用できません" do
      server1 = Tengine::Resource::Server.new(:name => "foo:bar")
      server1.valid?.should == false
      server1.errors[:name].should == [Tengine::Core::Validation::BASE_NAME.message]
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


  context :hostname_or_ipv4 do
    context "何も設定されていない場合" do
      subject{ Tengine::Resource::Server.new }
      its(:hostname_or_ipv4){ should == nil}
      its(:hostname_or_ipv4?){ should == false}
    end

    base_attrs = {
      :private_ip_address => '10.1.1.1',
      :private_dns_name   => 'local-name1',
      :ip_address         => '184.1.1.1',
      :dns_name           => 'public-name1',
    }

    context "address_orderの指定なし" do
      [
        [:private_ip_address, :private_dns_name  ],
        [:private_dns_name  , :ip_address],
        [:ip_address        , :dns_name],
      ].each do |(attr1, attr2)|
        context "#{attr1}と#{attr2}を設定した場合#{attr1}が優先されます" do
          subject do
            Tengine::Resource::Server.new(:addresses => {attr1.to_s => base_attrs[attr1], attr2.to_s => base_attrs[attr2]})
          end
          its(:hostname_or_ipv4){ should == base_attrs[attr1]}
          its(:hostname_or_ipv4?){ should == true}
        end
      end
    end

    context "address_orderの指定あり" do
      [
        [:private_ip_address, :ip_address],
        [:ip_address, :private_dns_name],
        [:private_dns_name, :dns_name],
      ].each do |(attr1, attr2)|
        context "#{attr1}と#{attr2}を設定した場合#{attr1}が優先されます" do
          subject do
            Tengine::Resource::Server.new(
              :address_order => %w[private_ip_address ip_address private_dns_name dns_name],
              :addresses => {attr1.to_s => base_attrs[attr1], attr2.to_s => base_attrs[attr2]})
          end
          its(:hostname_or_ipv4){ should == base_attrs[attr1]}
          its(:hostname_or_ipv4?){ should == true}
        end
      end
    end

    describe "フィクスチャから" do
      before do
        @fixture = GokuAtEc2ApNortheast.new
      end
      it do
        server1 = @fixture.hadoop_master_node
        server1.hostname_or_ipv4.should == "10.162.153.1"
      end
    end

  end


end
