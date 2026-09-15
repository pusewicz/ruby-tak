# frozen_string_literal: true

require "test_helper"

class ClientTest < Minitest::Test
  def create_client
    mock_socket = Minitest::Mock.new
    mock_socket.expect :peeraddr, ["AF_INET", 12_345, "localhost", "127.0.0.1"]
    RubyTAK::Client.new(mock_socket)
  end

  def test_extract_messages_raises_on_buffer_overflow
    client = create_client
    huge_data = "a" * (RubyTAK::Client::MAX_BUFFER_SIZE + 1)

    error = assert_raises(RuntimeError) { client.extract_messages(huge_data) }

    assert_match(/Buffer overflow/, error.message)
  end
end
