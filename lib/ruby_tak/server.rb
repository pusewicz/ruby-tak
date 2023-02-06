# frozen_string_literal: true

require "logger"
require "openssl"
require "ox"
require "socket"
require "forwardable"

module RubyTAK
  class Server
    attr_reader :logger

    def self.start
      new.start
    end

    def initialize(logger: Logger.new($stdout))
      @port = 8089
      @logger = logger
      @clients = ::Set.new
      logger.info("Starting #{self.class.name} v#{RubyTAK::VERSION} on port #{@port}")
      @server = TCPServer.new(@port)
      @context = OpenSSL::SSL::SSLContext.new
      setup_certificates
      @ssl_server = OpenSSL::SSL::SSLServer.new(@server, @context)
    end

    # TODO: Make things non-blocking
    # https://stackoverflow.com/questions/29858113/unable-to-make-socket-accept-non-blocking-ruby-2-2
    def start
      loop do
        socket = @ssl_server.accept
        handle_accept(socket)
      end
    end

    private

    def handle_accept(socket)
      client = Client.new(socket)
      @clients << client
      logger.info("CONN: #{client.inspect}")
      Thread.start(socket) do |sock|
        loop do
          data = sock.readpartial(4096)
          handle_data(client, data)
        rescue EOFError => e
          logger.info("EXIT: #{client.inspect}, #{e.inspect}")
          handle_disconnect(client)
          Thread.exit
        end
      end
    end

    def handle_data(client, data)
      parsed_data = parse_data(data)

      logger.info("RECV: #{client.inspect} -> #{parsed_data.inspect}")

      case parsed_data.name
      when "auth" then handle_auth(client, parsed_data)
      when "event" then handle_event(client, parsed_data)
      else
        raise "Unknown message type: #{data.inspect}"
      end
    end

    def handle_disconnect(client)
      @clients.delete(client)
    end

    def handle_auth(_client, _auth)
      # TODO: Implement username/password authentication

      logger.warn("AUTH: NotImplemented")
    end

    def handle_event(client, event)
      message = Message.from_ox_element(event)

      client.user = message if message.ident?

      if (dest_uids = message.marti_dest_uids)
        dest_uids.each do |_uid|
          dest_client = @clients.find { _1.uid == _uid }
          next unless dest_client

          logger.info("SEND: MARTI: #{dest_client.inspect} <- #{message.inspect} FROM #{client.inspect}")
          dest_client.write(message.to_xml)
        end
      else
        broadcast(message, client)
      end
    end

    def parse_data(data)
      parsed_data = MessageParser.parse(data)
      parsed_data = parsed_data.root if parsed_data.respond_to?(:root)
      parsed_data
    end

    def broadcast(message, source_client)
      data = message.to_xml

      @clients.each do |client|
        next if client == source_client

        logger.info "SEND: #{client.inspect} <- #{message.inspect} FROM #{source_client.inspect}"
        client.write(data)
      end
    end

    def setup_certificates
      rsa_cert = OpenSSL::X509::Certificate.new(File.read(RubyTAK.configuration.server_crt_path))
      rsa_pkey = OpenSSL::PKey::RSA.new(File.read(RubyTAK.configuration.server_key_path))
      @context.add_certificate(rsa_cert, rsa_pkey)
    end
  end
end
