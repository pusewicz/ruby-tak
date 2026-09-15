# frozen_string_literal: true

require "timeout"

module RubyTAK
  class Client
    attr_accessor :uid, :username
    attr_reader :remote_addr, :callsign, :group, :last_activity_at

    MAX_BUFFER_SIZE = 1024 * 1024 # 1MB
    WRITE_TIMEOUT = 5 # seconds

    def initialize(socket)
      @socket = socket
      @remote_addr = socket.peeraddr.last
      @uid = "__ANONYMOUS-#{SecureRandom.hex(6)}-#{@remote_addr}"
      @last_activity_at = Time.now
      @buffer = +""
    end

    def readpartial(maxlen)
      @socket.readpartial(maxlen)
    end

    def write(data)
      Timeout.timeout(WRITE_TIMEOUT) { @socket.write(data) }
    end

    def close
      @socket.close
    end

    def touch
      @last_activity_at = Time.now
    end

    def user=(event)
      @callsign = event.contact&.attributes&.fetch(:callsign, nil)
      @group = event.group&.attributes&.fetch(:name, nil)
      @uid = event.attributes[:uid]
    end

    def extract_messages(data)
      @buffer << data
      if @buffer.bytesize > MAX_BUFFER_SIZE
        bytesize = @buffer.bytesize
        @buffer.clear
        raise "Buffer overflow: #{bytesize} bytes"
      end

      messages = []

      # Extract complete messages (ending with </event> or </auth>)
      while (match = @buffer.match(%r{(.*?</(?:event|auth)>)}m))
        messages << match[1]
        @buffer = match.post_match
      end

      messages
    end
  end
end
