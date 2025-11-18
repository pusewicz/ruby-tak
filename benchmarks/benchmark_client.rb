# frozen_string_literal: true

require "socket"
require "securerandom"
require "time"

class BenchmarkClient
  attr_reader :uid, :stats

  def initialize(host: "localhost", port: 8089, uid: nil)
    @host = host
    @port = port
    @uid = uid || "BENCH-#{SecureRandom.hex(8)}"
    @stats = {
      messages_sent: 0,
      messages_received: 0,
      bytes_sent: 0,
      bytes_received: 0,
      errors: 0
    }
    @running = false
  end

  def connect
    @socket = TCPSocket.new(@host, @port)
    @running = true
    start_reader
  rescue StandardError
    @stats[:errors] += 1
    raise
  end

  def disconnect
    @running = false
    begin
      @socket&.close
    rescue StandardError
      nil
    end
    @reader_thread&.join(5) # Wait up to 5 seconds for reader thread to exit
  end

  def send_auth(username: "piotr", password: "password")
    xml = <<~XML.strip
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <auth><cot username="#{username}" password="#{password}" uid="#{@uid}"/></auth>
    XML
    write(xml)
  end

  def send_ident(callsign: nil, group: "Red")
    callsign ||= "BENCH-#{@uid[-6..]}"
    now = Time.now.utc.iso8601(3)
    stale = (Time.now + 300).utc.iso8601(3)

    xml = <<~XML.strip
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <event version="2.0" uid="#{@uid}" type="a-f-G-U-C" time="#{now}" start="#{now}" stale="#{stale}" how="m-g">
      <point lat="0.00000000" lon="0.00000000" hae="0.00000000" ce="9999999" le="9999999"/>
      <detail>
      <contact callsign="#{callsign}"/>
      <__group name="#{group}" role="Team Member"/>
      <takv platform="RubyTAK-Benchmark" version="1.0.0"/>
      </detail>
      </event>
    XML
    write(xml)
  end

  def send_ping
    now = Time.now.utc.iso8601(3)
    stale = (Time.now + 10).utc.iso8601(3)

    xml = <<~XML.strip
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <event version="2.0" uid="#{@uid}-ping" type="t-x-c-t" time="#{now}" start="#{now}" stale="#{stale}" how="m-g">
      <point lat="0.00000000" lon="0.00000000" hae="0.00000000" ce="9999999" le="9999999"/>
      <detail/>
      </event>
    XML
    write(xml)
  end

  def send_event(type: "a-f-G-U-C", lat: 0.0, lon: 0.0)
    now = Time.now.utc.iso8601(3)
    stale = (Time.now + 60).utc.iso8601(3)

    xml = <<~XML.strip
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <event version="2.0" uid="#{@uid}-#{SecureRandom.hex(4)}" type="#{type}" time="#{now}" start="#{now}" stale="#{stale}" how="m-g">
      <point lat="#{lat}" lon="#{lon}" hae="0.00000000" ce="999" le="999"/>
      <detail/>
      </event>
    XML
    write(xml)
  end

  def running?
    @running
  end

  private

  def write(data)
    @socket.write(data)
    @stats[:messages_sent] += 1
    @stats[:bytes_sent] += data.bytesize
  rescue StandardError
    @stats[:errors] += 1
    raise
  end

  def start_reader
    @reader_thread = Thread.new do
      while @running
        begin
          data = @socket.readpartial(4096)
          @stats[:messages_received] += data.scan(%r{</event>|</auth>}).size
          @stats[:bytes_received] += data.bytesize
        rescue IOError, Errno::EBADF
          # Normal disconnect or socket closed (IOError includes EOFError)
          @running = false
          break
        rescue StandardError
          # Actual error
          @stats[:errors] += 1
          @running = false
          break
        end
      end
    end
  end
end
