# frozen_string_literal: true

require "test_helper"
require "openssl"
require "stringio"
require "socket"

class ServerTest < Minitest::Test
  def setup
    @logger = Logger.new(StringIO.new)
    @logger.level = Logger::WARN
    @mock_tcp_server = Minitest::Mock.new
  end

  def create_server
    TCPServer.stub(:new, @mock_tcp_server) do
      RubyTAK::Server.new(logger: @logger)
    end
  end

  def test_initialize
    server = create_server

    assert_equal @logger, server.logger
  end

  def test_self_start_delegates_to_instance
    instance = Minitest::Mock.new
    instance.expect :start, nil

    RubyTAK::Server.stub :new, instance do
      RubyTAK::Server.start
    end

    instance.verify
  end

  def test_start_runs_accept_loop
    server = create_server
    @mock_tcp_server.expect(:accept, :fake_socket)
    @mock_tcp_server.expect(:accept, nil) { raise StopIteration }

    accepted = []
    server.stub(:accept_connection, ->(socket) { accepted << socket }) do
      server.stub(:start_connection_watchdog, nil) do
        server.stub(:ssl_context, OpenSSL::SSL::SSLContext.new) do
          server.start
        end
      end
    end

    assert_equal [:fake_socket], accepted
    @mock_tcp_server.verify
  end

  def test_start_raises_when_certificate_files_are_missing
    Dir.mktmpdir do |tmpdir|
      config = RubyTAK.configuration
      config.stub :certs_dir, Pathname.new(tmpdir) do
        config.stub :cot_ssl_port, 0 do
          server = RubyTAK::Server.new(logger: @logger)

          assert_raises(Errno::ENOENT) { server.start }
        end
      end
    end
  end

  def test_start_connection_watchdog_disconnects_timed_out_clients
    server = create_server
    mock_socket = Minitest::Mock.new
    mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]

    client = RubyTAK::Client.new(mock_socket)
    client.instance_variable_set(:@last_activity_at, Time.now - (RubyTAK::Server::CONNECTION_TIMEOUT + 1))
    server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients) << client
    end

    mock_socket.expect :close, nil
    mock_socket.expect(:close, nil) { raise IOError, "already closed" }

    sleep_calls = 0
    watcher = lambda do |*|
      sleep_calls += 1
      raise StopIteration if sleep_calls > 1
    end
    server.stub(:sleep, watcher) do
      server.send(:start_connection_watchdog).join
    end

    clients = server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients).to_a
    end

    assert_empty clients
    mock_socket.verify
  end

  def test_handle_disconnect_removes_client
    server = create_server
    mock_socket = Minitest::Mock.new
    mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]

    client = RubyTAK::Client.new(mock_socket)
    server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients) << client
    end

    mock_socket.expect :close, nil
    server.send(:handle_disconnect, client)

    clients = server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients).to_a
    end

    assert_empty clients
    mock_socket.verify
  end

  def test_handle_disconnect_ignores_unknown_client
    server = create_server
    mock_socket = Minitest::Mock.new
    mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]

    client = RubyTAK::Client.new(mock_socket)

    server.send(:handle_disconnect, client)

    clients = server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients).to_a
    end

    assert_empty clients
  end

  def test_handle_auth_success
    server = create_server
    mock_socket = Minitest::Mock.new
    mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]

    client = RubyTAK::Client.new(mock_socket)
    auth_xml = '<auth><cot username="piotr" password="password" uid="TEST-UID-123"/></auth>'
    message = RubyTAK::Message.new(auth_xml)

    server.send(:handle_auth, client, message)

    assert_equal "TEST-UID-123", client.uid
    assert_equal "piotr", client.username
  end

  def test_handle_auth_failure
    server = create_server
    mock_socket = Minitest::Mock.new
    mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]
    mock_socket.expect :close, nil
    mock_socket.expect :close, nil

    client = RubyTAK::Client.new(mock_socket)
    server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients) << client
    end

    auth_xml = '<auth><cot username="piotr" password="wrongpassword" uid="TEST-UID-123"/></auth>'
    message = RubyTAK::Message.new(auth_xml)

    server.send(:handle_auth, client, message)

    clients = server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients).to_a
    end

    assert_empty clients
    mock_socket.verify
  end

  def test_handle_auth_missing_cot
    server = create_server
    mock_socket = Minitest::Mock.new
    mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]
    mock_socket.expect :close, nil
    mock_socket.expect :close, nil

    client = RubyTAK::Client.new(mock_socket)
    server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients) << client
    end

    message = RubyTAK::Message.new("<auth></auth>")

    server.send(:handle_auth, client, message)

    clients = server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients).to_a
    end

    assert_empty clients
    mock_socket.verify
  end

  def test_handle_ping
    server = create_server
    mock_socket = Minitest::Mock.new
    mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]

    client = RubyTAK::Client.new(mock_socket)
    ping_xml = <<~XML
      <event version="2.0" uid="TEST-ping" type="t-x-c-t" time="2023-02-09T05:34:07.851Z" start="2023-02-09T05:34:07.851Z" stale="2023-02-09T05:34:17.851Z" how="m-g">
        <point lat="0.00000000" lon="0.00000000" hae="0.00000000" ce="9999999" le="9999999"/>
        <detail/>
      </event>
    XML
    message = RubyTAK::Message.new(ping_xml.strip)

    mock_socket.expect :write, nil do |data|
      data.include?("takPong") && data.include?("t-x-c-t-r")
    end

    server.send(:handle_ping, client, message)

    mock_socket.verify
  end

  def test_handle_ping_write_failure
    server = create_server
    mock_socket = Minitest::Mock.new
    mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]

    client = RubyTAK::Client.new(mock_socket)
    server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients) << client
    end

    ping_xml = <<~XML
      <event version="2.0" uid="TEST-ping" type="t-x-c-t" time="2023-02-09T05:34:07.851Z" start="2023-02-09T05:34:07.851Z" stale="2023-02-09T05:34:17.851Z" how="m-g">
        <point lat="0.00000000" lon="0.00000000" hae="0.00000000" ce="9999999" le="9999999"/>
        <detail/>
      </event>
    XML
    message = RubyTAK::Message.new(ping_xml.strip)

    mock_socket.expect(:write, nil) { raise Errno::EPIPE }
    mock_socket.expect :close, nil

    server.send(:handle_ping, client, message)

    clients = server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients).to_a
    end

    assert_empty clients
    mock_socket.verify
  end

  def test_broadcast
    server = create_server

    mock_socket1 = Minitest::Mock.new
    mock_socket1.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]
    client1 = RubyTAK::Client.new(mock_socket1)

    mock_socket2 = Minitest::Mock.new
    mock_socket2.expect :peeraddr, ["AF_INET", 12_346, "localhost", "127.0.0.2"]
    client2 = RubyTAK::Client.new(mock_socket2)

    server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients) << client1
      server.instance_variable_get(:@clients) << client2
    end

    event_xml = <<~XML
      <event version="2.0" uid="TEST-123" type="a-f-G-E-V-C" how="h-e" time="2023-01-24T09:17:49Z" start="2023-01-24T09:17:49Z" stale="2023-01-24T09:19:49Z">
        <point lat="40.0" lon="0.0" hae="0.0" ce="9999999.0" le="9999999.0"/>
        <detail/>
      </event>
    XML
    message = RubyTAK::Message.new(event_xml.strip)

    mock_socket2.expect(:write, nil) do |data|
      data.include?("TEST-123")
    end

    server.send(:broadcast, message, client1)

    mock_socket2.verify
  end

  def test_broadcast_handles_write_failure
    server = create_server

    mock_socket1 = Minitest::Mock.new
    mock_socket1.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]
    client1 = RubyTAK::Client.new(mock_socket1)

    mock_socket2 = Minitest::Mock.new
    mock_socket2.expect :peeraddr, ["AF_INET", 12_346, "localhost", "127.0.0.2"]
    client2 = RubyTAK::Client.new(mock_socket2)

    server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients) << client1
      server.instance_variable_get(:@clients) << client2
    end

    event_xml = <<~XML
      <event version="2.0" uid="TEST-123" type="a-f-G-E-V-C" how="h-e" time="2023-01-24T09:17:49Z" start="2023-01-24T09:17:49Z" stale="2023-01-24T09:19:49Z">
        <point lat="40.0" lon="0.0" hae="0.0" ce="9999999.0" le="9999999.0"/>
        <detail/>
      </event>
    XML
    message = RubyTAK::Message.new(event_xml.strip)

    mock_socket2.expect(:write, nil) { raise Errno::EPIPE }
    mock_socket2.expect :close, nil

    server.send(:broadcast, message, client1)

    clients = server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients).to_a
    end

    assert_equal 1, clients.size
    assert_equal client1, clients[0]
    mock_socket2.verify
  end

  def test_handle_event_ident
    server = create_server
    mock_socket = Minitest::Mock.new
    mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]

    client = RubyTAK::Client.new(mock_socket)

    ident_xml = <<~XML
      <event version="2.0" uid="TEST-UID" type="a-f-G-E-V-C" how="h-e" time="2023-01-24T09:17:49Z" start="2023-01-24T09:17:49Z" stale="2023-01-24T09:19:49Z">
        <point lat="40.0" lon="0.0" hae="0.0" ce="9999999.0" le="9999999.0"/>
        <detail>
          <contact callsign="TestUser"/>
          <__group name="TestGroup" role="Team Member"/>
          <takv device="Test" platform="Test" os="Test" version="1.0"/>
        </detail>
      </event>
    XML
    message = RubyTAK::Message.new(ident_xml.strip)

    server.send(:handle_event, client, message)

    assert_equal "TestUser", client.callsign
    assert_equal "TestGroup", client.group
    assert_equal "TEST-UID", client.uid
  end

  def test_handle_event_ping
    server = create_server
    mock_socket = Minitest::Mock.new
    mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]

    client = RubyTAK::Client.new(mock_socket)
    ping_xml = <<~XML
      <event version="2.0" uid="TEST-ping" type="t-x-c-t" time="2023-02-09T05:34:07.851Z" start="2023-02-09T05:34:07.851Z" stale="2023-02-09T05:34:17.851Z" how="m-g">
        <point lat="0.00000000" lon="0.00000000" hae="0.00000000" ce="9999999" le="9999999"/>
        <detail/>
      </event>
    XML
    message = RubyTAK::Message.new(ping_xml.strip)

    mock_socket.expect :write, nil do |data|
      data.include?("takPong") && data.include?("t-x-c-t-r")
    end

    server.send(:handle_event, client, message)

    mock_socket.verify
  end

  def test_handle_event_with_marti_dest
    server = create_server

    mock_socket1 = Minitest::Mock.new
    mock_socket1.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]
    client1 = RubyTAK::Client.new(mock_socket1)
    client1.uid = "SENDER-UID"

    mock_socket2 = Minitest::Mock.new
    mock_socket2.expect :peeraddr, ["AF_INET", 12_346, "localhost", "127.0.0.2"]
    client2 = RubyTAK::Client.new(mock_socket2)
    client2.uid = "DEST-UID"

    server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients) << client1
      server.instance_variable_get(:@clients) << client2
    end

    marti_xml = <<~XML
      <event version="2.0" uid="SENDER-UID" type="b-m-p-s-m" how="h-g-i-g-o" time="2023-01-24T09:17:49Z" start="2023-01-24T09:17:49Z" stale="2023-01-24T09:19:49Z">
        <point lat="0.0" lon="0.0" hae="0.0" ce="9999999.0" le="9999999.0"/>
        <detail>
          <link uid="DEST-UID" relation="p-p" type="a-f-G-E-V-C"/>
          <remarks>Test message</remarks>
          <marti>
            <dest callsign="Dest" uid="DEST-UID"/>
          </marti>
        </detail>
      </event>
    XML
    message = RubyTAK::Message.new(marti_xml.strip)

    mock_socket2.expect(:write, nil) do |data|
      data.include?("SENDER-UID")
    end

    server.send(:handle_event, client1, message)

    mock_socket2.verify
  end

  def test_handle_accept_eof_disconnects_client
    server = create_server
    mock_socket = Minitest::Mock.new
    mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]
    mock_socket.expect(:readpartial, nil) { raise EOFError }
    mock_socket.expect :close, nil

    server.send(:handle_accept, mock_socket)

    sleep 0.3

    clients = server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients).to_a
    end

    assert_empty clients
    mock_socket.verify
  end

  def test_handle_accept_standard_error_disconnects_client
    log_output = StringIO.new
    logger = Logger.new(log_output)
    logger.level = Logger::WARN
    server = TCPServer.stub(:new, @mock_tcp_server) { RubyTAK::Server.new(logger: logger) }
    mock_socket = Minitest::Mock.new
    mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]
    mock_socket.expect(:readpartial, nil) { raise "boom" }
    mock_socket.expect :close, nil

    server.send(:handle_accept, mock_socket)

    sleep 0.3

    assert_match(/Client error/, log_output.string)
    mock_socket.verify
  end

  def test_handle_event_with_marti_dest_write_failure
    server = create_server

    mock_socket1 = Minitest::Mock.new
    mock_socket1.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]
    client1 = RubyTAK::Client.new(mock_socket1)
    client1.uid = "SENDER-UID"

    mock_socket2 = Minitest::Mock.new
    mock_socket2.expect :peeraddr, ["AF_INET", 12_346, "localhost", "127.0.0.2"]
    client2 = RubyTAK::Client.new(mock_socket2)
    client2.uid = "DEST-UID"

    server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients) << client1
      server.instance_variable_get(:@clients) << client2
    end

    marti_xml = <<~XML
      <event version="2.0" uid="SENDER-UID" type="b-m-p-s-m" how="h-g-i-g-o" time="2023-01-24T09:17:49Z" start="2023-01-24T09:17:49Z" stale="2023-01-24T09:19:49Z">
        <point lat="0.0" lon="0.0" hae="0.0" ce="9999999.0" le="9999999.0"/>
        <detail>
          <link uid="DEST-UID" relation="p-p" type="a-f-G-E-V-C"/>
          <remarks>Test message</remarks>
          <marti>
            <dest callsign="Dest" uid="DEST-UID"/>
          </marti>
        </detail>
      </event>
    XML
    message = RubyTAK::Message.new(marti_xml.strip)

    mock_socket2.expect(:write, nil) { raise Errno::EPIPE }
    mock_socket2.expect :close, nil

    server.send(:handle_event, client1, message)

    clients = server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients).to_a
    end

    assert_equal 1, clients.size
    assert_equal client1, clients[0]
    mock_socket2.verify
  end

  def test_handle_accept_max_connections
    server = create_server

    # Fill up to max connections
    RubyTAK::Server::MAX_CONNECTIONS.times do
      mock_socket = Minitest::Mock.new
      mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]
      client = RubyTAK::Client.new(mock_socket)
      server.instance_variable_get(:@clients_mutex).synchronize do
        server.instance_variable_get(:@clients) << client
      end
    end

    # Try to add one more
    reject_socket = Minitest::Mock.new
    reject_socket.expect :close, nil

    server.send(:handle_accept, reject_socket)

    reject_socket.verify
  end

  def test_handle_accept_successful_connection
    server = create_server
    mock_socket = Minitest::Mock.new
    mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]

    event_xml = <<~XML
      <event version="2.0" uid="TEST-123" type="a-f-G-E-V-C" how="h-e" time="2023-01-24T09:17:49Z" start="2023-01-24T09:17:49Z" stale="2023-01-24T09:19:49Z">
        <point lat="40.0" lon="0.0" hae="0.0" ce="9999999.0" le="9999999.0"/>
        <detail>
          <contact callsign="TestUser"/>
          <__group name="TestGroup" role="Team Member"/>
          <takv device="Test" platform="Test" os="Test" version="1.0"/>
        </detail>
      </event>
    XML

    # First read returns event, second raises IOError
    mock_socket.expect(:readpartial, event_xml.strip, [4096])
    mock_socket.expect(:readpartial, nil) { raise IOError }
    mock_socket.expect :close, nil

    # Call handle_accept which should add client immediately
    server.send(:handle_accept, mock_socket)

    # Client should be added before thread processes
    clients = server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients).to_a
    end

    assert_equal 1, clients.size

    # Wait for thread to process and disconnect
    sleep 0.3

    # Verify the event was processed by checking the callsign was set
    # and then client was disconnected
    assert_equal "TestUser", clients[0].callsign
    assert_equal "TEST-123", clients[0].uid

    # Client should now be disconnected and removed
    clients = server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients).to_a
    end

    assert_empty clients
  end

  def test_handle_data_with_event
    server = create_server
    mock_socket = Minitest::Mock.new
    mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]

    client = RubyTAK::Client.new(mock_socket)

    event_xml = <<~XML
      <event version="2.0" uid="TEST-123" type="a-f-G-E-V-C" how="h-e" time="2023-01-24T09:17:49Z" start="2023-01-24T09:17:49Z" stale="2023-01-24T09:19:49Z">
        <point lat="40.0" lon="0.0" hae="0.0" ce="9999999.0" le="9999999.0"/>
        <detail>
          <contact callsign="TestUser"/>
          <__group name="TestGroup" role="Team Member"/>
          <takv device="Test" platform="Test" os="Test" version="1.0"/>
        </detail>
      </event>
    XML

    server.send(:handle_data, client, event_xml.strip)

    assert_equal "TestUser", client.callsign
    assert_equal "TEST-123", client.uid
  end

  def test_handle_data_with_auth
    server = create_server
    mock_socket = Minitest::Mock.new
    mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]

    client = RubyTAK::Client.new(mock_socket)
    auth_xml = '<auth><cot username="piotr" password="password" uid="AUTH-UID-456"/></auth>'

    server.send(:handle_data, client, auth_xml)

    assert_equal "AUTH-UID-456", client.uid
    assert_equal "piotr", client.username
  end

  def test_handle_data_with_unknown_message_type
    log_output = StringIO.new
    logger = Logger.new(log_output)
    logger.level = Logger::WARN
    server = TCPServer.stub(:new, @mock_tcp_server) { RubyTAK::Server.new(logger: logger) }
    mock_socket = Minitest::Mock.new
    mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]

    client = RubyTAK::Client.new(mock_socket)
    unknown_xml = "<unknown><data/></unknown>"

    server.send(:handle_data, client, unknown_xml)

    assert_match(/Unknown message type/, log_output.string)
  end

  def test_accept_connection_rejects_when_max_connections_reached
    server = create_server

    RubyTAK::Server::MAX_CONNECTIONS.times do
      mock_socket = Minitest::Mock.new
      mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]
      client = RubyTAK::Client.new(mock_socket)
      server.instance_variable_get(:@clients_mutex).synchronize do
        server.instance_variable_get(:@clients) << client
      end
    end

    reject_socket = Minitest::Mock.new
    reject_socket.expect :close, nil

    server.send(:accept_connection, reject_socket)

    reject_socket.verify
  end

  def test_accept_connection_handles_io_error_during_handshake
    server = create_server
    raw_socket = Minitest::Mock.new
    raw_socket.expect :close, nil

    fake_ssl_socket = Minitest::Mock.new
    fake_ssl_socket.expect :sync_close=, nil, [true]
    fake_ssl_socket.expect(:accept, nil) { raise IOError, "closed" }

    OpenSSL::SSL::SSLSocket.stub :new, fake_ssl_socket do
      server.stub :ssl_context, OpenSSL::SSL::SSLContext.new do
        server.send(:accept_connection, raw_socket).join
      end
    end

    raw_socket.verify
    fake_ssl_socket.verify
  end

  def test_accept_connection_handles_unexpected_error_during_handshake
    server = create_server
    raw_socket = Minitest::Mock.new
    raw_socket.expect :close, nil

    fake_ssl_socket = Minitest::Mock.new
    fake_ssl_socket.expect :sync_close=, nil, [true]
    fake_ssl_socket.expect(:accept, nil) { raise Errno::ECONNABORTED }

    OpenSSL::SSL::SSLSocket.stub :new, fake_ssl_socket do
      server.stub :ssl_context, OpenSSL::SSL::SSLContext.new do
        server.send(:accept_connection, raw_socket).join
      end
    end

    raw_socket.verify
    fake_ssl_socket.verify

    in_flight = server.instance_variable_get(:@in_flight_count)

    assert_equal 0, in_flight
  end

  def test_accept_connection_logs_handshake_failure_at_info_level
    log_output = StringIO.new
    logger = Logger.new(log_output)
    logger.level = Logger::INFO
    server = TCPServer.stub(:new, @mock_tcp_server) { RubyTAK::Server.new(logger: logger) }

    raw_socket = Minitest::Mock.new
    raw_socket.expect :close, nil

    fake_ssl_socket = Minitest::Mock.new
    fake_ssl_socket.expect :sync_close=, nil, [true]
    fake_ssl_socket.expect(:accept, nil) { raise OpenSSL::SSL::SSLError, "handshake failure" }

    OpenSSL::SSL::SSLSocket.stub :new, fake_ssl_socket do
      server.stub :ssl_context, OpenSSL::SSL::SSLContext.new do
        server.send(:accept_connection, raw_socket).join
      end
    end

    assert_match(/TLS handshake failed/, log_output.string)
    raw_socket.verify
    fake_ssl_socket.verify
  end

  def test_accept_connection_times_out_slow_handshake
    log_output = StringIO.new
    logger = Logger.new(log_output)
    logger.level = Logger::INFO
    server = TCPServer.stub(:new, @mock_tcp_server) { RubyTAK::Server.new(logger: logger) }

    raw_socket = Minitest::Mock.new
    raw_socket.expect :close, nil

    fake_ssl_socket = Minitest::Mock.new
    fake_ssl_socket.expect :sync_close=, nil, [true]
    fake_ssl_socket.expect(:accept, nil) { sleep 1 }

    original_timeout = RubyTAK::Server::HANDSHAKE_TIMEOUT
    RubyTAK::Server.send(:remove_const, :HANDSHAKE_TIMEOUT)
    RubyTAK::Server.const_set(:HANDSHAKE_TIMEOUT, 0.05)

    begin
      OpenSSL::SSL::SSLSocket.stub :new, fake_ssl_socket do
        server.stub :ssl_context, OpenSSL::SSL::SSLContext.new do
          server.send(:accept_connection, raw_socket).join
        end
      end
    ensure
      RubyTAK::Server.send(:remove_const, :HANDSHAKE_TIMEOUT)
      RubyTAK::Server.const_set(:HANDSHAKE_TIMEOUT, original_timeout)
    end

    assert_match(/TLS handshake timed out/, log_output.string)
    raw_socket.verify
    fake_ssl_socket.verify

    in_flight = server.instance_variable_get(:@in_flight_count)

    assert_equal 0, in_flight
  end

  def test_accept_connection_rejects_when_in_flight_handshakes_reach_max_connections
    server = create_server
    server.instance_variable_set(:@in_flight_count, RubyTAK::Server::MAX_CONNECTIONS)

    reject_socket = Minitest::Mock.new
    reject_socket.expect :close, nil

    server.send(:accept_connection, reject_socket)

    reject_socket.verify

    clients = server.instance_variable_get(:@clients_mutex).synchronize do
      server.instance_variable_get(:@clients).to_a
    end

    assert_empty clients
  end

  def with_tls_server
    Dir.mktmpdir do |tmpdir|
      config = RubyTAK.configuration
      config.stub :certs_dir, Pathname.new(tmpdir) do
        capture_io { RubyTAK::CLI.new.run(%w[certificate ca]) }
        capture_io { RubyTAK::CLI.new.run(%w[certificate server]) }

        config.stub :cot_ssl_port, 0 do
          server = RubyTAK::Server.new(logger: @logger)
          tcp_server = server.instance_variable_get(:@server)
          port = tcp_server.addr[1]
          server_thread = Thread.new { server.start }
          server_thread.report_on_exception = false
          sleep 0.1

          begin
            yield server, port
          ensure
            tcp_server.close
            server_thread.kill
            begin
              server_thread.join(1)
            rescue StandardError
              nil
            end
          end
        end
      end
    end
  end

  def test_accept_connection_completes_tls_handshake_and_processes_auth
    with_tls_server do |server, port|
      tcp_socket = TCPSocket.new("127.0.0.1", port)
      client_ssl_context = OpenSSL::SSL::SSLContext.new
      client_ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
      ssl_socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, client_ssl_context)
      ssl_socket.connect

      ssl_socket.write('<auth><cot username="piotr" password="password" uid="TLS-TEST-UID"/></auth>')
      sleep 0.2

      clients = server.instance_variable_get(:@clients_mutex).synchronize do
        server.instance_variable_get(:@clients).to_a
      end

      assert_equal 1, clients.size
      assert_equal "TLS-TEST-UID", clients[0].uid
    ensure
      ssl_socket&.close
    end
  end

  def test_accept_connection_handles_non_tls_client_without_crashing
    with_tls_server do |server, port|
      tcp_socket = TCPSocket.new("127.0.0.1", port)
      tcp_socket.write("not a tls client hello\n")
      sleep 0.2

      clients = server.instance_variable_get(:@clients_mutex).synchronize do
        server.instance_variable_get(:@clients).to_a
      end

      assert_empty clients
    ensure
      tcp_socket&.close
    end
  end
end
