require 'navy'

class Commodore::ConvoyQueueHandler
  attr_reader :etcd

  def handle_create(params, request)
    @etcd = params[:etcd]
    consume_message(params, request) do |message|
      convoy = message["name"]
      logger = params[:logger] || Navy::Logger.new
      logger.info "#{message["request"]}: #{convoy}"
      case message["request"]
      when "create"
        manifest = message["manifest"]
        Commodore::ConvoyCreator.new(convoy, manifest).create!(params)
      when "destroy"
        Commodore::ConvoyDestroyer.new(convoy).destroy!(params)
      end
    end
  end

  private

  def consume_message(params, request)
    id = params["id"]
    message = JSON.parse(request.node.value)
    yield message
  end
end
