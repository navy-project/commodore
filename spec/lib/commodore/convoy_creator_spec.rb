require 'spec_helper'
require 'json'

describe Commodore::ConvoyCreator do
  let(:etcd) { MockEtcd.new }

  let(:params) do
    {
      :env => 'theenv',
      :cluster => 'the-cluster.com',
      :etcd => etcd
    }
  end

  let(:convoy) { "aconvoyid" }

  let(:manifest) do
    <<-YAML
    apps:
      app1:
        image: app_image_1
        modes:
          modea: foo
          modeb: bar
        links:
          - dep1
      app2:
        image: app_image_2
        links:
          - dep2
    environments:
      theenv:
        dependencies:
          dep1:
            image: dep_image_1
          dep2:
            image: dep_image_2
        pre:
          app1:
            - task 1
            - task 2
        post:
          app2:
            - task a
            - taks b
    YAML
  end

  subject { described_class.new(convoy, manifest) }

  describe "#create!" do
    before :each do
      subject.create!(params)
    end

    it "sets the manifest for the named convoy" do
      set_manifest = etcd.get("/navy/convoys/aconvoyid/manifest")
      expect(set_manifest).to eq manifest
    end

    it "puts a create message on the container queue for each conatiner" do
      queued = etcd.getQueue('/navy/queues/containers')
      expect(queued.length).to eq 7
    end

    it "sets desired state of given dependencies" do
      queued = etcd.getQueue('/navy/queues/containers')
      message = queued.detect { |d| d["name"] == "aconvoyid_dep1" }
      expect(message["request"]).to eq "create"
      desired = message["desired"]
      expect(desired["specification"]["name"]).to eq "dep1"
      expect(desired["state"]).to eq "running"
      expect(desired["specification"]["image"]).to eq "dep_image_1"
      expect(desired["specification"]["container_name"]).to eq "aconvoyid_dep1"
      expect(desired["dependencies"]).to eq []
      message = queued.detect { |d| d["name"] == "aconvoyid_dep2" }
      desired = message["desired"]
      expect(desired["specification"]["image"]).to eq "dep_image_2"
      expect(desired["dependencies"]).to eq []
    end

    it "sets desired state of given pre tasks" do
      queued = etcd.getQueue('/navy/queues/containers')
      message = queued.detect { |d| d["name"] == "aconvoyid_app1_pretasks" }
      expect(message["request"]).to eq "create"
      desired = message["desired"]
      expect(desired["state"]).to eq "completed"
      expect(desired["specification"]["image"]).to eq "app_image_1"
      expect(desired["specification"]["name"]).to eq "app1"
      expect(desired["specification"]["container_name"]).to eq "aconvoyid_app1_pretasks"
      expect(desired["dependencies"]).to eq ['aconvoyid_dep1']
    end


    it "sets desired state of given applications, per mode" do
      queued = etcd.getQueue('/navy/queues/containers')
      message = queued.detect { |d| d["name"] == "aconvoyid_app1_modea_1" }
      expect(message["request"]).to eq "create"
      desired = message["desired"]
      expect(desired["state"]).to eq "running"
      expect(desired["specification"]["image"]).to eq "app_image_1"
      expect(desired["specification"]["name"]).to eq "app1"
      expect(desired["specification"]["container_name"]).to eq "aconvoyid_app1_modea_1"
      expect(desired["dependencies"]).to eq ['aconvoyid_dep1', 'aconvoyid_app1_pretasks']
      message = queued.detect { |d| d["name"] == "aconvoyid_app1_modeb_1" }
      desired = message["desired"]
      expect(desired["state"]).to eq "running"
      expect(desired["specification"]["image"]).to eq "app_image_1"
      message = queued.detect { |d| d["name"] == "aconvoyid_app2_1" }
      desired = message["desired"]
      expect(desired["specification"]["image"]).to eq "app_image_2"
      expect(desired["dependencies"]).to eq ['aconvoyid_dep2']
    end

    it "sets desired state of given post tasks" do
      queued = etcd.getQueue('/navy/queues/containers')
      message = queued.detect { |d| d["name"] == "aconvoyid_app2_posttasks" }
      expect(message["request"]).to eq "create"
      desired = message["desired"]

      expect(desired["state"]).to eq "completed"
      expect(desired["specification"]["image"]).to eq "app_image_2"
      expect(desired["specification"]["name"]).to eq "app2"
      expect(desired["specification"]["container_name"]).to eq "aconvoyid_app2_posttasks"
      expect(desired["dependencies"]).to eq ['aconvoyid_app2_1']
    end

    it "saves list of containers requested" do
      queued = etcd.getQueue('/navy/queues/containers')
      containers = queued.map {|m| m["name"] }
      containers.each do |container|
        key = "/navy/convoys/#{convoy}/containers/#{container}"
        expect(etcd.get(key)).to be
      end
    end

    it "saves a map of container names to convoy" do
      queued = etcd.getQueue('/navy/queues/containers')
      containers = queued.map {|m| m["name"] }
      containers.each do |container|
        key = "/navy/convoy_names/#{container}"
        expect(etcd.get(key)).to eq convoy
      end
    end

  end
end
