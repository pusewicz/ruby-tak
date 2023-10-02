# frozen_string_literal: true

module RubyTAK
  class Client
    extend Forwardable

    def_delegators :@socket, :readpartial, :close, :write

    attr_accessor :uid, :username
    attr_reader :remote_addr, :callsign, :group

    def initialize(socket)
      @socket = socket
      @remote_addr = socket.peeraddr.last
      @uid = "__ANONYMOUS-#{SecureRandom.hex(6)}-#{@remote_addr}"
    end

    def user=(event)
      @callsign = event.contact.attributes[:callsign]
      @group = event.group.attributes[:name]
      @uid = event.attributes[:uid]
    end
  end
end
