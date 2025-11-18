# frozen_string_literal: true

require "ox"
require "socket"

module RubyTAK
  class Server
    USERS = {
      "piotr" => "password"
    }.freeze

    MAX_CONNECTIONS = 200
    CONNECTION_TIMEOUT = 300 # seconds

    attr_reader :logger

    def self.start
      new.start
    end

    def initialize(logger: RubyTAK.logger)
      @port = RubyTAK.configuration.cot_ssl_port
      @logger = logger
      @clients = ::Set.new
      @clients_mutex = Mutex.new
      logger.info("Starting #{self.class.name} v#{RubyTAK::VERSION} on port #{@port}")
      @server = TCPServer.new("0.0.0.0", @port)
    end

    # TODO: Make things non-blocking
    # https://stackoverflow.com/questions/29858113/unable-to-make-socket-accept-non-blocking-ruby-2-2
    def start
      start_connection_watchdog
      loop do
        socket = @server.accept
        handle_accept(socket)
      end
    end

    private

    def start_connection_watchdog
      Thread.start do
        loop do
          sleep 30
          now = Time.now
          timed_out = @clients_mutex.synchronize do
            @clients.select { |c| now - c.last_activity_at > CONNECTION_TIMEOUT }
          end
          timed_out.each do |c|
            logger.warn("TIMEOUT: #{c.uid}")
            handle_disconnect(c)
            begin
              c.close
            rescue StandardError
              nil
            end
          end
        end
      end
    end

    def handle_accept(socket)
      client_count = @clients_mutex.synchronize { @clients.size }
      if client_count >= MAX_CONNECTIONS
        logger.warn("MAX_CONNECTIONS reached, rejecting connection")
        socket.close
        return
      end

      client = Client.new(socket)
      @clients_mutex.synchronize { @clients << client }
      logger.debug("Client count: #{client_count + 1}")
      Thread.start(client) do |c|
        logger.debug("ACCEPT: #{c.uid}")
        loop do
          data = c.readpartial(4096)
          c.touch
          messages = c.extract_messages(data)
          messages.each { |msg| handle_data(c, msg) }
        rescue IOError, Errno::ECONNRESET
          logger.debug("Client disconnected: #{c.uid}")
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
      result, client_count = @clients_mutex.synchronize do
        [@clients.delete(client), @clients.size]
      end
      return unless result

      logger.info("DISCONNECT: #{client.uid}")
      logger.debug("Client count: #{client_count}")
      begin
        client.close
      rescue StandardError
        nil
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
          dest_client = @clients_mutex.synchronize { @clients.find { it.uid == uid } }
          next unless dest_client

          logger.debug("SEND: MARTI: #{dest_client.uid} <- #{message} FROM #{client.uid}")
          begin
            dest_client.write(message.to_xml)
          rescue Errno::EPIPE, Errno::ECONNRESET, IOError, Timeout::Error => e
            logger.debug("Write failed to #{dest_client.uid}: #{e.class}")
            handle_disconnect(dest_client)
          end
        end
      else
        broadcast(message, client)
      end
    end

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
      logger.debug("PONG: #{client.uid}")
      begin
        client.write(MessageBuilder.pong.to_s)
      rescue Errno::EPIPE, Errno::ECONNRESET, IOError, Timeout::Error => e
        logger.debug("Write failed to #{client.uid}: #{e.class}")
        handle_disconnect(client)
      end
    end

    def broadcast(message, source_client)
      data = message.to_s
      logger.debug "BROADCAST: #{source_client.uid} -> #{data}"

      clients_to_broadcast = @clients_mutex.synchronize { @clients.to_a }
      clients_to_broadcast.each do |client|
        next if client == source_client

        begin
          client.write(data)
        rescue Errno::EPIPE, Errno::ECONNRESET, IOError, Timeout::Error => e
          logger.debug("Write failed to #{client.uid}: #{e.class}")
          handle_disconnect(client)
        end
      end
    end
  end
end
