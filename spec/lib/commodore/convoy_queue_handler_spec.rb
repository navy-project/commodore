require 'spec_helper'
require 'json'

describe Commodore::ConvoyQueueHandler do
  let(:etcd) { MockEtcd.new }

  let(:params) do
    {
      :env => 'theenv',
      'id' => '1234',
      :cluster => 'the-cluster.com',
      :etcd => etcd
    }
  end

  let(:node) { double :value => message.to_json }
  let(:request) { double :node => node, :key => '/some/key' }

  describe "#handle_create" do
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

    context "When a create message is received" do
      let(:message) do
        {
          :request => :create,
          :name => 'aconvoyid',
          :manifest => manifest
        }
      end


      it "creates the convoy" do
        creator = double
        expect(Commodore::ConvoyCreator).to receive(:new).with("aconvoyid", manifest) { creator }
        expect(creator).to receive(:create!).with(params)
        subject.handle_create(params, request)
      end


    end

    describe "when a :destroy message is recieved" do
      let(:message) do
        {
          :request => :destroy,
          :name => 'aconvoyid'
        }
      end


      it "handles removal of the manifest" do
        destroyer = double
        expect(Commodore::ConvoyDestroyer).to receive(:new).with("aconvoyid") { destroyer }
        expect(destroyer).to receive(:destroy!).with(params)
        subject.handle_create(params, request)
      end
    end

  end
end
