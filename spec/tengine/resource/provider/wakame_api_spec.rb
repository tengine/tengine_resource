# -*- coding: utf-8 -*-
require 'spec_helper'
require 'apis/wakame'

describe Tengine::Resource::Provider::Wakame do

  subject {
    Tengine::Resource::Provider::Wakame.delete_all
    Tengine::Resource::Provider::Wakame.create(
      :name => "wakameTest1",
      :description => "provided by wakame / tama",
      :connection_settings => {
        :test => true,
        :options => {
          # 仮想サーバの状態
          :describe_instances_file => File.join(
            File.dirname(__FILE__), "./test_files/describe_instances.json"),
          # 仮想サーバイメージの状態
          :describe_images_file => File.join(
            File.dirname(__FILE__), "./test_files/describe_images.json"),
          # 仮想サーバ起動時
          :run_instances_file => File.join(
            File.dirname(__FILE__), "./test_files/run_instances.json"),
          # 仮想サーバ停止時
          :terminate_instances_file => File.join(
            File.dirname(__FILE__), "./test_files/terminate_instances.json"),
          # 物理サーバの状態
          :describe_host_nodes_file  => File.join(
            File.dirname(__FILE__), "./test_files/describe_host_nodes.json"),
          # 仮想サーバスペックの状態
          :describe_instance_specs_file => File.join(
            File.dirname(__FILE__), "./test_files/describe_instance_specs.json"),
        }
      })
  }

  describe "test mode" do
    it "仮想サーバの状態" do
      subject.describe_instances_for_api.should == [{
          "aws_kernel_id" => "",
          "aws_launch_time" => "2011-10-18T06:51:16Z",
          "tags" => {},
          "aws_reservation_id" => "",
          "aws_owner" => "a-shpoolxx",
          "instance_lifecycle" => "",
          "block_device_mappings" => [{
              "ebs_volume_id" => "",
              "ebs_status" => "",
              "ebs_attach_time" => "",
              "ebs_delete_on_termination" => false,
              "device_name" => ""
            }],
          "ami_launch_index" => "",
          "root_device_name" => "",
          "aws_ramdisk_id" => "",
          "aws_availability_zone" => "hp-demohost",
          #"aws_groups" => nil,
          "spot_instance_request_id" => "",
          #"ssh_key_name" => nil,
          "virtualization_type" => "",
          "placement_group_name" => "",
          "requester_id" => "",
          "aws_instance_id" => "i-jria301q",
          "aws_product_codes" => [],
          "client_token" => "",
          "private_ip_address" => ["192.168.2.188"],
          "architecture" => "x86_64",
          "aws_state_code" => 0,
          "aws_image_id" => "wmi-lucid5",
          "root_device_type" => "",
          "ip_address" => "nw-data=192.168.2.188",
          "dns_name" => "nw-data=jria301q.shpoolxx.vdc.local",
          "monitoring_state" => "",
          "aws_instance_type" => "is-demospec",
          "aws_state" => "running",
          "private_dns_name" => "jria301q.shpoolxx.vdc.local",
          "aws_reason" => ""
        }]
    end

    it "仮想サーバイメージの状態" do
      subject.describe_images_for_api.should == [{
          "root_device_name" => "",
          "aws_ramdisk_id" => "",
          "block_device_mappings" => [{
              "ebs_snapshot_id" => "",
              "ebs_volume_size" => 0,
              "ebs_delete_on_termination" => false,
              "device_name" => ""
            }],
          "aws_is_public" => false,
          "virtualization_type" => "",
          "image_owner_alias" => "",
          "aws_id" => "wmi-lucid4",
          "aws_architecture" => "x86",
          "root_device_type" => "",
          "aws_location" => "--- \n:snapshot_id: snap-lucid4\n",
          "aws_image_type" => "",
          "name" => "",
          "aws_state" => "init",
          "description" => "ubuntu-10.04_with-metadata_kvm_i386.raw volume",
          "aws_kernel_id" => "",
          "tags" => {},
          "aws_owner" => "a-shpoolzz"
        }]
    end

    it "仮想サーバの起動" do
      subject.run_instances_for_api.should == [{
          "aws_image_id" => "wmi-lucid4",
          "aws_reason" => "",
          "aws_state_code" => "0",
          "aws_owner" => "a-shopoolzz",
          "aws_instance_id" => "i-9pia8e7g",
          "aws_reservation_id" => "r-aabbccdd",
          "aws_state" => "init",
          "dns_name" => "",
          "ssh_key_name" => "ssh-xxxxxx",
          "aws_groups" => [""],
          "private_dns_name" => "",
          "aws_instance_type" => "is-small",
          "aws_launch_time" => "2008-1-1T00:00:00.000Z",
          "aws_ramdisk_id" => "",
          "aws_kernel_id" => "",
          "ami_launch_index" => "0",
          "aws_availability_zone" => "",
        }]
    end

    it "仮想サーバの停止" do
      subject.terminate_instances_for_api.should == [{
          "aws_current_state_name" => "",
          "aws_prev_state_name" => "",
          "aws_prev_state_code" => 0,
          "aws_current_state_code" => 0,
          "aws_instance_id" => "i-9pia8e7g"
        }]
    end

    it "物理サーバの状態" do
      subject.describe_host_nodes_for_api.should == [{
          "status" => "online",
          "updated_at" => "2011-10-18T03:53:24Z",
          "account_id" => "a-shpoolzz",
          "offering_cpu_cores" => 120,
          "offering_memory_size" => 350000,
          "arch" => "x86_64",
          "hypervisor" => "kvm",
          "created_at" => "2011-10-18T03:53:24Z",
          "name" => "testhost",
          "uuid" => "hp-testhost",
          "id" => "hp-testhost"
        }]
    end

    it "仮想サーバスペックの状態" do
      subject.describe_instance_specs_for_api.should == [{
          "cpu_cores" => 2,
          "memory_size" => 512,
          "arch" => "x86_64",
          "hypervisor" => "kvm",
          "updated_at" => "2011-10-28T02:58:57Z",
          "account_id" => "a-shpoolzz",
          "vifs" => "--- \neth0: \n  :bandwidth: 100000\n  :index: 0\n",
          "quota_weight" => 1.0,
          "id" => "is-testspec",
          "created_at" => "2011-10-28T02:58:57Z",
          "drives" => "--- \nephemeral1: \n  :type: :local\n  :size: 100\n  :index: 0\n",
          "uuid" => "is-testspec"
        }]
    end

  end
end
