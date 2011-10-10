# -*- coding: utf-8 -*-
require 'spec_helper'

describe Tengine::Resource::VirtualServer do

  before(:all) do
    @fixture = GokuAtEc2West.new
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

end
