# frozen_string_literal: true

require "openssl"
require "ox"
require "socket"
require "timeout"

module RubyTAK
  class Server
    USERS = {
      "piotr" => "password"
    }.freeze

    MAX_CONNECTIONS = 200
    CONNECTION_TIMEOUT = 300 # seconds
    HANDSHAKE_TIMEOUT = 10 # seconds

    attr_reader :logger

    def self.start
      new.start
    end

    def initialize(logger: RubyTAK.logger)
      @port = RubyTAK.configuration.cot_ssl_port
      @logger = logger
      @clients = ::Set.new
      @clients_mutex = Mutex.new
      @in_flight_count = 0
      @in_flight_mutex = Mutex.new
      logger.info("Starting #{self.class.name} v#{RubyTAK::VERSION} on port #{@port}")
      @server = TCPServer.new("0.0.0.0", @port)
    end

    # TODO: Make things non-blocking
    # https://stackoverflow.com/questions/29858113/unable-to-make-socket-accept-non-blocking-ruby-2-2
    def start
      ssl_context
      start_connection_watchdog
      loop do
        socket = @server.accept
        accept_connection(socket)
      end
    rescue Interrupt
      shutdown
    end

    private

    def shutdown
      logger.info("Shutting down...")
      clients_to_close = @clients_mutex.synchronize { @clients.to_a }
      clients_to_close.each { |client| handle_disconnect(client) }
      @server.close
    end

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

    def accept_connection(socket)
      if at_capacity?
        logger.warn("MAX_CONNECTIONS reached, rejecting connection")
        socket.close
        return
      end

      @in_flight_mutex.synchronize { @in_flight_count += 1 }

      Thread.start(socket) do |raw_socket|
        begin
          ssl_socket = OpenSSL::SSL::SSLSocket.new(raw_socket, ssl_context)
          ssl_socket.sync_close = true
          Timeout.timeout(HANDSHAKE_TIMEOUT) { ssl_socket.accept }
        rescue OpenSSL::SSL::SSLError => e
          logger.info("TLS handshake failed: #{e.class} #{e.message}")
          raw_socket.close
          Thread.exit
        rescue IOError, Errno::ECONNRESET => e
          logger.debug("Connection closed during TLS handshake: #{e.class}")
          raw_socket.close
          Thread.exit
        rescue Timeout::Error
          logger.info("TLS handshake timed out after #{HANDSHAKE_TIMEOUT}s")
          raw_socket.close
          Thread.exit
        rescue StandardError => e
          logger.error("Unexpected error during TLS handshake: #{e.class} #{e.message}")
          raw_socket.close
          Thread.exit
        ensure
          @in_flight_mutex.synchronize { @in_flight_count -= 1 }
        end

        handle_accept(ssl_socket)
      end
    end

    def at_capacity?
      client_count = @clients_mutex.synchronize { @clients.size }
      in_flight_count = @in_flight_mutex.synchronize { @in_flight_count }
      (client_count + in_flight_count) >= MAX_CONNECTIONS
    end

    def ssl_context
      @ssl_context ||= begin
        config = RubyTAK.configuration
        context = OpenSSL::SSL::SSLContext.new
        context.cert = OpenSSL::X509::Certificate.new(File.read(config.server_crt_path))
        context.key = OpenSSL::PKey::RSA.new(File.read(config.server_key_path))
        context.verify_mode = OpenSSL::SSL::VERIFY_NONE
        context
      end
    end

    def handle_accept(socket)
      if at_capacity?
        logger.warn("MAX_CONNECTIONS reached, rejecting connection")
        socket.close
        return
      end

      client = Client.new(socket)
      client_count = @clients_mutex.synchronize do
        @clients << client
        @clients.size
      end
      logger.debug("Client count: #{client_count}")
      Thread.start(client) do |c|
        logger.debug("ACCEPT: #{c.uid}")
        loop do
          data = c.readpartial(4096)
          c.touch
          messages = c.extract_messages(data)
          messages.each { |msg| handle_data(c, msg) }
        rescue EOFError
          logger.debug("Client disconnected (EOF): #{c.uid}")
          handle_disconnect(c)
          Thread.exit
        rescue IOError, Errno::ECONNRESET
          logger.debug("Client disconnected: #{c.uid}")
          handle_disconnect(c)
          Thread.exit
        rescue StandardError => e
          logger.error("Client error: #{c.uid} #{e.class} #{e.message}")
          logger.error(e.backtrace&.join("\n") || "(no backtrace)")
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
        logger.warn("Unknown message type: #{message.name} #{data.inspect}")
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
      if message.cot.nil?
        logger.error("AUTH: #{client.uid} -> FAILED, malformed auth message (no cot)")
        handle_disconnect(client)
        client.close
        return
      end

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
