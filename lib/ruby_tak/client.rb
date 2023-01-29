# frozen_string_literal: true

module RubyTAK
  class Client
    extend Forwardable

    def_delegators :@socket, :write

    attr_reader :remote_addr, :uid, :callsign, :group

    def initialize(socket)
      @socket = socket

      @remote_addr = socket.peeraddr.last
    end

    def user=(event)
      @callsign = event.contact.attributes[:callsign]
      @group = event.group.attributes[:name]
      @uid = event.attributes[:uid]
    end

    def inspect
      attrs = {
        remote_addr: @remote_addr,
        uid: @uid,
        callsign: @callsign,
        group: @group
      }
      "#{self.class.name}(#{attrs.map { |k, v| "#{k}=#{v.inspect}" }.join(", ")})"
    end
  end
end
