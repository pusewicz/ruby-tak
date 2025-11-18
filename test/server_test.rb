# frozen_string_literal: true

require "test_helper"
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
    server = create_server
    mock_socket = Minitest::Mock.new
    mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]

    client = RubyTAK::Client.new(mock_socket)
    unknown_xml = "<unknown><data/></unknown>"

    error = assert_raises(RuntimeError) do
      server.send(:handle_data, client, unknown_xml)
    end

    assert_match(/Unknown message type/, error.message)
  end
end
