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
      logger.debug("Client count: #{@clients.size}")
      Thread.start(client) do |c|
        logger.debug("ACCEPT: #{c.uid}")
        loop do
          data = c.readpartial(4096)
          handle_data(c, data)
        rescue EOFError => e
          logger.error("EXIT: #{c.uid}, #{e.inspect}")
          handle_disconnect(c)
          Thread.exit
        end
      end
    end

    def handle_data(client, data)
      logger.debug("RECV: #{client.uid} #{data}")

      message = Message.new(data)

      case message.name
      when "event" then handle_event(client, message)
      when "auth" then handle_auth(client, message)
      else
        raise "Unknown message type: #{data.inspect}"
      end
    end

    def handle_disconnect(client)
      @clients.delete(client).tap do |result|
        logger.info("DISCONNECT: #{client.uid}") if result
        logger.debug("Client count: #{@clients.size}")
      end
    end

    def handle_event(client, message)
      if message.ident?
        logger.debug("IDENT: #{client.uid} -> #{message}")
      elsif message.ping?
        logger.debug("PING: #{client.uid}")
      else
        logger.debug("EVENT: #{client.uid} -> #{message}")
      end
      client.user = message if message.ident?

      return handle_ping(client, message) if message.ping?

      if (dest_uids = message.marti_dest_uids)
        dest_uids.each do |uid|
          dest_client = @clients.find { _1.uid == uid }
          next unless dest_client

          logger.debug("SEND: MARTI: #{dest_client.uid} <- #{message} FROM #{client.uid}")
          dest_client.write(message.to_xml)
        end
      else
        broadcast(message, client)
      end
    end

    USERS = {
      "piotr" => "password"
    }.freeze

    def handle_auth(client, message)
      # <?xml version=\"1.0\"?>\n<auth><cot username=\"piotr\" password=\"password\" uid=\"ANDROID-82cd68af1fb8fd80\"/></auth>
      username, password, uid = message.cot.attributes.values_at(:username, :password, :uid)

      if USERS[username] == password
        logger.debug("AUTH: #{client.uid} -> #{username}@#{uid}")
        client.uid = uid
        client.username = username
      else
        logger.error("AUTH: #{client.uid} -> #{username} FAILED, incorrect username or password")
        handle_disconnect(client)
        client.close
      end
    end

    def handle_ping(client, _ping)
      message = MessageBuilder.pong.to_s
      logger.debug("PONG: #{client.uid}")
      client.write(message)
    end

    def broadcast(message, source_client)
      data = message.to_s
      logger.debug "BROADCAST: #{source_client.uid} -> #{data}"

      @clients.each do |client|
        next if client == source_client

        client.write(data)
      end
    end
  end
end
