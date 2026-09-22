# frozen_string_literal: true

require "test_helper"

class ClientTest < Minitest::Test
  # A fake socket whose #write and #close each take measurable time,
  # so concurrent callers would overlap unless Client serializes access.
  class SlowSocket
    attr_reader :max_concurrent

    def initialize
      @in_flight = 0
      @max_concurrent = 0
      @mutex = Mutex.new
    end

    def peeraddr
      ["AF_INET", 12_345, "localhost", "127.0.0.1"]
    end

    def write(_data)
      track { sleep 0.05 }
    end

    def close
      track { sleep 0.05 }
    end

    private

    def track
      @mutex.synchronize do
        @in_flight += 1
        @max_concurrent = [@max_concurrent, @in_flight].max
      end
      yield
      @mutex.synchronize { @in_flight -= 1 }
    end
  end

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

  def test_write_serializes_concurrent_writers
    socket = SlowSocket.new
    client = RubyTAK::Client.new(socket)

    threads = Array.new(5) { Thread.new { client.write("data") } }
    threads.each(&:join)

    assert_equal 1, socket.max_concurrent
  end

  def test_close_is_mutually_exclusive_with_write
    socket = SlowSocket.new
    client = RubyTAK::Client.new(socket)

    write_thread = Thread.new { client.write("data") }
    sleep 0.01
    close_thread = Thread.new { client.close }
    [write_thread, close_thread].each(&:join)

    assert_equal 1, socket.max_concurrent
  end
end
