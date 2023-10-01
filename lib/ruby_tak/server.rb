# frozen_string_literal: true

require "ox"
require "socket"
require "forwardable"

module RubyTAK
  class Server
    attr_reader :logger

    def self.start
      new.start
    end

    def initialize(logger: RubyTAK.logger)
      @port = RubyTAK.configuration.cot_ssl_port
      @logger = logger
      @clients = ::Set.new
      logger.info("Starting #{self.class.name} v#{RubyTAK::VERSION} on port #{@port}")
      @server = TCPServer.new("0.0.0.0", @port)
    end

    # TODO: Make things non-blocking
    # https://stackoverflow.com/questions/29858113/unable-to-make-socket-accept-non-blocking-ruby-2-2
    def start
      loop do
        socket = @server.accept
        handle_accept(socket)
      end
    end

    private

    def handle_accept(socket)
      client = Client.new(socket)
      @clients << client
      Thread.start(client) do |c|
        logger.info("ACCEPT: #{c.inspect}")
        loop do
          data = c.readpartial(4096)
          handle_data(c, data)
        rescue EOFError => e
          logger.info("EXIT: #{c.inspect}, #{e.inspect}")
          handle_disconnect(c)
          Thread.exit
        end
      end
    end

    def handle_data(client, data)
      logger.info("RECV: #{client.inspect} -> #{data.inspect}")

      message = Message.new(data)

      case message.name
      when "event" then handle_event(client, message)
      else
        raise "Unknown message type: #{data.inspect}"
      end
    end

    def handle_disconnect(client)
      @clients.delete(client).tap do |result|
        logger.info("DISCONNECT: #{client.inspect}, #{result.inspect}")
      end
    end

    def handle_event(client, message)
      client.user = message if message.ident?

      return handle_ping(client, message) if message.ping?

      if (dest_uids = message.marti_dest_uids)
        dest_uids.each do |uid|
          dest_client = @clients.find { _1.uid == uid }
          next unless dest_client

          logger.info("SEND: MARTI: #{dest_client.inspect} <- #{message.inspect} FROM #{client.inspect}")
          dest_client.write(message.to_xml)
        end
      else
        broadcast(message, client)
      end
    end

    def handle_ping(client, _ping)
      client.write(MessageBuilder.pong)
    end

    def broadcast(message, source_client)
      data = message.to_xml

      @clients.each do |client|
        next if client == source_client

        logger.info "SEND: #{client.inspect} <- #{message.inspect} FROM #{source_client.inspect}"
        client.write(data)
      end
    end
  end
end
