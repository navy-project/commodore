require 'spec_helper'

describe Commodore::ConvoyDestroyer do
  let(:etcd) { MockEtcd.new }

  let(:params) do
    {
      :env => 'theenv',
      :cluster => 'the-cluster.com',
      :etcd => etcd
    }
  end

  let(:convoy) { "aconvoyid" }

  let(:containers) { ["one", "two", "three"] }

  subject { described_class.new(convoy) }

  describe "#destroy!" do
    before :each do
      containers.each do |container|
        etcd.set("/navy/convoys/#{convoy}/containers/#{container}", "")
      end
      subject.destroy!(params)
    end

    it "puts destroy message for each associted container" do
      queued = etcd.getQueue('/navy/queues/containers')
      expect(queued.length).to eq containers.length
      containers.each do |container|
        message = queued.detect { |m| m["name"] == container }
        expect(message["request"]).to eq "destroy"
      end
    end

    it "removes the convoy data from etcd" do
      convoys = etcd.ls("/navy/convoys")
      expect(convoys).to eq []
    end
  end

end
