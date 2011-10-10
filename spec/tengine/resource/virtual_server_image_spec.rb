# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Resource::VirtualServerImage do
  valid_attributes1 = {
    :name => "provider1"
  }.freeze

  context "nameは必須" do
    it "正常系" do
      Tengine::Resource::VirtualServerImage.delete_all
      credential1 = Tengine::Resource::VirtualServerImage.new(valid_attributes1)
      credential1.valid?.should == true
    end

    [:name].each do |key|
      it "#{key}なし" do
        attrs = valid_attributes1.dup
        attrs.delete(key)
        credential1 = Tengine::Resource::VirtualServerImage.new(attrs)
        credential1.valid?.should == false
      end
    end

  end

  context "nameはユニーク" do
    before do
      Tengine::Resource::VirtualServerImage.delete_all
      @credential1 = Tengine::Resource::VirtualServerImage.create!(valid_attributes1)
    end

    it "同じ名前で登録されているものが存在する場合エラー" do
      expect{
        @credential1 = Tengine::Resource::VirtualServerImage.create!(valid_attributes1)
      }.to raise_error(Mongoid::Errors::Validations, "Validation failed - Name is already taken.")
    end
  end

  context "nameはベース名として定義される文字列です" do
    it "スラッシュ'/’はリソース識別子で使われるのでnameには使用できません" do
      server1 = Tengine::Resource::VirtualServerImage.new(:name => "foo/bar")
      server1.valid?.should == false
      server1.errors[:name].should == [Tengine::Core::Validation::BASE_NAME.message]
    end

    it "コロン':'はリソース識別子で使われるのでnameには使用できません" do
      server1 = Tengine::Resource::VirtualServerImage.new(:name => "foo:bar")
      server1.valid?.should == false
      server1.errors[:name].should == [Tengine::Core::Validation::BASE_NAME.message]
    end
  end

end
