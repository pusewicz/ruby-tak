#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "benchmark_client"

# Benchmark: Message Throughput
# Tests how many messages per second the server can handle

class MessageThroughputBenchmark
  def initialize(num_clients: 50, duration: 30, message_rate: 10, host: "localhost", port: 8089)
    @num_clients = num_clients
    @duration = duration
    @message_rate = message_rate # messages per second per client
    @host = host
    @port = port
    @clients = []
    @sender_threads = []
  end

  def run
    puts "=" * 80
    puts "Message Throughput Benchmark"
    puts "=" * 80
    puts "Clients: #{@num_clients}"
    puts "Duration: #{@duration}s"
    puts "Message rate: #{@message_rate} msgs/sec per client"
    puts "Expected total: #{@num_clients * @message_rate * @duration} messages"
    puts "Host: #{@host}:#{@port}"
    puts

    # Phase 1: Connect and authenticate
    puts "Phase 1: Connecting #{@num_clients} clients..."
    @num_clients.times do |i|
      client = BenchmarkClient.new(host: @host, port: @port)
      begin
        client.connect
        client.send_auth
        client.send_ident
        @clients << client
        print "." if ((i + 1) % 10).zero?
      rescue StandardError => e
        puts "\nFailed to setup client #{i + 1}: #{e.message}"
      end
    end
    puts
    puts "Connected #{@clients.size}/#{@num_clients} clients"
    sleep 1
    puts

    # Phase 2: Send messages continuously
    puts "Phase 2: Sending messages for #{@duration} seconds..."
    start_time = Time.now
    send_messages
    actual_duration = Time.now - start_time
    puts
    puts "Completed in #{actual_duration.round(2)}s"
    puts

    # Phase 3: Cleanup
    puts "Phase 3: Disconnecting clients..."
    @clients.each(&:disconnect)
    puts

    # Results
    print_results(actual_duration)
  end

  private

  def send_messages
    interval = 1.0 / @message_rate
    running = true

    # Start a thread for each client to send messages
    @clients.each do |client|
      thread = Thread.new do
        message_count = 0
        start = Time.now

        while running && (Time.now - start) < @duration
          begin
            # Alternate between different message types
            case message_count % 3
            when 0
              client.send_event(lat: rand(-90.0..90.0), lon: rand(-180.0..180.0))
            when 1
              client.send_ping
            when 2
              client.send_event(type: "a-f-G-E-S")
            end
            message_count += 1
            sleep interval
          rescue StandardError => e
            puts "\nError sending message: #{e.message}"
            break
          end
        end
      end
      @sender_threads << thread
    end

    # Wait for all threads to complete
    @sender_threads.each(&:join)
    running = false
  end

  def print_results(duration)
    total_stats = @clients.each_with_object(Hash.new(0)) do |client, stats|
      client.stats.each { |k, v| stats[k] += v }
    end

    puts "=" * 80
    puts "Results"
    puts "=" * 80
    puts "Active clients: #{@clients.size}"
    puts "Actual duration: #{duration.round(2)}s"
    puts "Total messages sent: #{total_stats[:messages_sent]}"
    puts "Total messages received: #{total_stats[:messages_received]}"
    puts "Total bytes sent: #{format_bytes(total_stats[:bytes_sent])}"
    puts "Total bytes received: #{format_bytes(total_stats[:bytes_received])}"
    puts "Total errors: #{total_stats[:errors]}"
    puts
    puts "Messages sent/second: #{(total_stats[:messages_sent] / duration).round(2)}"
    puts "Messages received/second: #{(total_stats[:messages_received] / duration).round(2)}"
    puts "Throughput sent: #{format_bytes(total_stats[:bytes_sent] / duration)}/s"
    puts "Throughput received: #{format_bytes(total_stats[:bytes_received] / duration)}/s"
    puts "Average per client: #{(total_stats[:messages_sent] / @clients.size.to_f).round(2)} messages"
    puts "=" * 80
  end

  def format_bytes(bytes)
    if bytes < 1024
      "#{bytes.round(2)} B"
    elsif bytes < 1024 * 1024
      "#{(bytes / 1024.0).round(2)} KB"
    else
      "#{(bytes / (1024.0 * 1024)).round(2)} MB"
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  num_clients = (ARGV[0] || 50).to_i
  duration = (ARGV[1] || 30).to_i
  message_rate = (ARGV[2] || 10).to_i
  host = ARGV[3] || "localhost"
  port = (ARGV[4] || 8089).to_i

  benchmark = MessageThroughputBenchmark.new(
    num_clients: num_clients,
    duration: duration,
    message_rate: message_rate,
    host: host,
    port: port
  )
  benchmark.run
end
