#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "benchmark_client"

# Benchmark: Concurrent Connections
# Tests server behavior under many simultaneous connections

class ConcurrentConnectionsBenchmark
  def initialize(num_clients: 100, host: "localhost", port: 8089)
    @num_clients = num_clients
    @host = host
    @port = port
    @clients = []
  end

  def run
    puts "=" * 80
    puts "Concurrent Connections Benchmark"
    puts "=" * 80
    puts "Clients: #{@num_clients}"
    puts "Host: #{@host}:#{@port}"
    puts

    start_time = Time.now

    # Phase 1: Connect all clients
    puts "Phase 1: Connecting #{@num_clients} clients..."
    connect_time = measure do
      @num_clients.times do |i|
        client = BenchmarkClient.new(host: @host, port: @port)
        begin
          client.connect
          @clients << client
          print "." if (i + 1) % 10 == 0
        rescue => e
          puts "\nFailed to connect client #{i + 1}: #{e.message}"
        end
      end
    end
    puts
    puts "Connected #{@clients.size}/#{@num_clients} clients in #{connect_time.round(2)}s"
    puts

    # Phase 2: Authenticate all clients
    puts "Phase 2: Authenticating clients..."
    auth_time = measure do
      @clients.each(&:send_auth)
    end
    puts "Authenticated in #{auth_time.round(2)}s"
    sleep 0.5
    puts

    # Phase 3: Send ident messages
    puts "Phase 3: Sending ident messages..."
    ident_time = measure do
      @clients.each(&:send_ident)
    end
    puts "Sent idents in #{ident_time.round(2)}s"
    sleep 0.5
    puts

    # Phase 4: Send pings from all clients
    puts "Phase 4: Sending ping messages..."
    ping_time = measure do
      @clients.each(&:send_ping)
    end
    puts "Sent pings in #{ping_time.round(2)}s"
    sleep 1
    puts

    # Phase 5: Keep connections alive for a period
    puts "Phase 5: Holding connections for 10 seconds..."
    sleep 10
    puts

    # Phase 6: Disconnect all clients
    puts "Phase 6: Disconnecting clients..."
    disconnect_time = measure do
      @clients.each(&:disconnect)
    end
    puts "Disconnected in #{disconnect_time.round(2)}s"
    puts

    # Results
    total_time = Time.now - start_time
    print_results(total_time)
  end

  private

  def measure
    start = Time.now
    yield
    Time.now - start
  end

  def print_results(total_time)
    total_stats = @clients.each_with_object(Hash.new(0)) do |client, stats|
      client.stats.each { |k, v| stats[k] += v }
    end

    puts "=" * 80
    puts "Results"
    puts "=" * 80
    puts "Total time: #{total_time.round(2)}s"
    puts "Successful connections: #{@clients.size}/#{@num_clients}"
    puts "Total messages sent: #{total_stats[:messages_sent]}"
    puts "Total messages received: #{total_stats[:messages_received]}"
    puts "Total bytes sent: #{format_bytes(total_stats[:bytes_sent])}"
    puts "Total bytes received: #{format_bytes(total_stats[:bytes_received])}"
    puts "Total errors: #{total_stats[:errors]}"
    puts "Messages/second: #{(total_stats[:messages_sent] / total_time).round(2)}" if total_time > 0
    puts "=" * 80
  end

  def format_bytes(bytes)
    if bytes < 1024
      "#{bytes} B"
    elsif bytes < 1024 * 1024
      "#{(bytes / 1024.0).round(2)} KB"
    else
      "#{(bytes / (1024.0 * 1024)).round(2)} MB"
    end
  end
end

if __FILE__ == $0
  num_clients = (ARGV[0] || 100).to_i
  host = ARGV[1] || "localhost"
  port = (ARGV[2] || 8089).to_i

  benchmark = ConcurrentConnectionsBenchmark.new(num_clients: num_clients, host: host, port: port)
  benchmark.run
end
