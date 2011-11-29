# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Resource::Provider do

  valid_attributes1 = {
    :name => "provider1"
  }.freeze

  context "nameは必須" do
    it "正常系" do
      Tengine::Resource::Provider.delete_all
      credential1 = Tengine::Resource::Provider.new(valid_attributes1)
      credential1.valid?.should == true
    end

    [:name].each do |key|
      it "#{key}なし" do
        attrs = valid_attributes1.dup
        attrs.delete(key)
        credential1 = Tengine::Resource::Provider.new(attrs)
        credential1.valid?.should == false
      end
    end

  end

  context "nameはユニーク" do
    before do
      Tengine::Resource::Provider.delete_all
      @credential1 = Tengine::Resource::Provider.create!(valid_attributes1)
    end

    it "同じ名前で登録されているものが存在する場合エラー" do
      expect{
        @credential1 = Tengine::Resource::Provider.create!(valid_attributes1)
      }.to raise_error(Mongoid::Errors::Validations, "Validation failed - Name is already taken.")
    end
  end

  context "nameはベース名として定義される文字列です" do
    it "スラッシュ'/’はリソース識別子で使われるのでnameには使用できません" do
      server1 = Tengine::Resource::Provider.new(:name => "foo/bar")
      server1.valid?.should == false
      server1.errors[:name].should == [Tengine::Core::Validation::BASE_NAME.message]
    end

    it "コロン':'はリソース識別子で使われるのでnameには使用できません" do
      server1 = Tengine::Resource::Provider.new(:name => "foo:bar")
      server1.valid?.should == false
      server1.errors[:name].should == [Tengine::Core::Validation::BASE_NAME.message]
    end
  end

  context "nameで検索" do
    before do
      Tengine::Resource::Provider.delete_all
      @fixture = GokuAtEc2ApNortheast.new
      @provider1 = @fixture.provider
    end

    context "見つかる場合" do
      it "find_by_name" do
        found_credential = nil
        lambda{
          found_credential = Tengine::Resource::Provider.find_by_name(@provider1.name)
        }.should_not raise_error
        found_credential.should_not be_nil
        found_credential.id.should == @provider1.id
      end

      it "find_by_name!" do
        found_credential = nil
        lambda{
          found_credential = Tengine::Resource::Provider.find_by_name!(@provider1.name)
        }.should_not raise_error
        found_credential.should_not be_nil
        found_credential.id.should == @provider1.id
      end
    end

    context "見つからない場合" do
      it "find_by_name" do
        found_credential = Tengine::Resource::Provider.find_by_name("unexist_name").should == nil
      end

      it "find_by_name!" do
        lambda{
          found_credential = Tengine::Resource::Provider.find_by_name!("unexist_name")
        }.should raise_error(Tengine::Core::FindByName::Error)
      end
    end

  end


  describe "<BUG>仮想サーバ起動画面から仮想サーバを起動すると仮想サーバが２重に登録され、仮想サーバ一覧でも２つ表示される" do
    before do
      Tengine::Resource::VirtualServer.delete_all
      Tengine::Resource::Provider.delete_all
      test_files_dir = File.expand_path("test_files", File.dirname(__FILE__))
      @provider = Tengine::Resource::Provider::Wakame.create!(:name => "Wakame",
        :connection_settings => {
          :test => true,
          :options => {
            # :describe_instance_specs_file => File.expand_path('describe_instance_specs.json', test_files_dir)  # 仮想サーバスペックの状態
            # :describe_images_file         => File.expand_path('describe_images.json',         test_files_dir), # 仮想サーバイメージの状態
            # :terminate_instances_file     => File.expand_path('terminate_instances.json',     test_files_dir), # 仮想サーバ停止時
            # :describe_host_nodes_file     => File.expand_path('describe_host_nodes.json',     test_files_dir), # 物理サーバの状態
            # 仮想サーバを一台だけ起動して、describe_instancesもその情報を返す
            :run_instances_file           => File.expand_path('41_run_instances_1_virtual_servers.json',           test_files_dir), # 仮想サーバ起動時
            :describe_instances_file      => File.expand_path('14_describe_instances_after_run_1_instance.json',      test_files_dir), # 仮想サーバの状態
          }
        })
    end

    it "プロバイダへのリクエスト送信直後、登録処理を行う前に、tengine_resource_watchdが登録を行ってしまうと、二重登録される" do
      expect{
        expect{
          @provider.create_virtual_servers(
            "test",
            mock(:server_image1, :provided_id => "img-aaaa"),
            mock(:server_type1, :provided_id => "type1"),
            mock(:physical1, :provided_id => "server1"),
            "", 1) do
            # このブロックはテスト用に使われるもので、リクエストを送った直後、データを登録する前に呼び出されます。
            @provider.virtual_server_watch
          end
        }.to_not raise_error
      }.to change(Tengine::Resource::VirtualServer, :count).by(1) # 1台だけ起動される
    end
  end


end
