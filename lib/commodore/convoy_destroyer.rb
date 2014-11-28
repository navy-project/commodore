module Commodore
  class ConvoyDestroyer
    attr_reader :convoy

    def initialize(convoy)
      @convoy = convoy
    end

    def destroy!(params)
      etcd = params[:etcd]
      containers(etcd).each do |container|
        destroy(container, etcd)
      end
      clear_convoy(etcd)
    end

    private

    def clear_convoy(etcd)
      etcd.delete("/navy/convoys/#{convoy}", :recursive => true)
    end

    def destroy(container, etcd)
      message = {
        "request" => :destroy,
        "name" => container
      }
      etcd.queueJSON("/navy/queues/containers", message)
    end

    def containers(etcd)
      etcd.ls("/navy/convoys/#{convoy}/containers").map {|c| File.basename(c) }
    end
  end
end
