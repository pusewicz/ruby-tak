# frozen_string_literal: true

require "timeout"

module RubyTAK
  class Client
    extend Forwardable

    def_delegators :@socket, :readpartial, :close

    attr_accessor :uid, :username
    attr_reader :remote_addr, :callsign, :group, :last_activity_at

    WRITE_TIMEOUT = 5 # seconds

    def initialize(socket)
      @socket = socket
      @remote_addr = socket.peeraddr.last
      @uid = "__ANONYMOUS-#{SecureRandom.hex(6)}-#{@remote_addr}"
      @last_activity_at = Time.now
      @buffer = String.new
    end

    def write(data)
      Timeout.timeout(WRITE_TIMEOUT) { @socket.write(data) }
    end

    def touch
      @last_activity_at = Time.now
    end

    def user=(event)
      @callsign = event.contact.attributes[:callsign]
      @group = event.group.attributes[:name]
      @uid = event.attributes[:uid]
    end

    def extract_messages(data)
      @buffer << data
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
