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
      puts
      puts "Identifying #{remote_addr} as #{@callsign} in #{@group} with UID #{@uid}"
      puts
    end

    def inspect
      "#{self.class.name}(remote_addr=#{@remote_addr.inspect}, uid=#{@uid.inspect}, callsign=#{@callsign.inspect}, group=#{@group.inspect})"
    end
  end
end
