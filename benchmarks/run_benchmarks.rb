#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"

# Benchmark Runner
# Runs various benchmarks against a RubyTAK server

class BenchmarkRunner
  BENCHMARKS = {
    "connections" => {
      file: "concurrent_connections.rb",
      description: "Test concurrent connections handling"
    },
    "throughput" => {
      file: "message_throughput.rb",
      description: "Test message throughput capacity"
    },
    "all" => {
      description: "Run all benchmarks"
    }
  }.freeze

  def initialize
    @options = {
      host: "localhost",
      port: 8089,
      benchmark: "all"
    }
  end

  def run(args = ARGV)
    parse_options(args)

    if @options[:list]
      list_benchmarks
      return
    end

    puts "RubyTAK Benchmark Suite"
    puts "Server: #{@options[:host]}:#{@options[:port]}"
    puts

    if @options[:benchmark] == "all"
      run_all_benchmarks
    else
      run_benchmark(@options[:benchmark])
    end
  end

  private

  def parse_options(args)
    OptionParser.new do |opts|
      opts.banner = "Usage: run_benchmarks.rb [options]"

      opts.on("-b", "--benchmark NAME", "Benchmark to run (connections, throughput, all)") do |b|
        @options[:benchmark] = b
      end

      opts.on("-h", "--host HOST", "Server host (default: localhost)") do |h|
        @options[:host] = h
      end

      opts.on("-p", "--port PORT", Integer, "Server port (default: 8089)") do |p|
        @options[:port] = p
      end

      opts.on("-l", "--list", "List available benchmarks") do
        @options[:list] = true
      end

      opts.on("--help", "Show this help") do
        puts opts
        exit
      end
    end.parse!(args)
  end

  def list_benchmarks
    puts "Available benchmarks:"
    puts
    BENCHMARKS.each do |name, info|
      puts "  #{name.ljust(15)} - #{info[:description]}"
    end
  end

  def run_all_benchmarks
    BENCHMARKS.each do |name, info|
      next if name == "all"
      run_benchmark(name)
      puts "\n\n"
    end
  end

  def run_benchmark(name)
    benchmark = BENCHMARKS[name]
    unless benchmark
      puts "Unknown benchmark: #{name}"
      puts "Use --list to see available benchmarks"
      exit 1
    end

    puts "Running benchmark: #{name}"
    puts benchmark[:description]
    puts

    script_path = File.join(__dir__, benchmark[:file])
    unless File.exist?(script_path)
      puts "Benchmark script not found: #{script_path}"
      exit 1
    end

    # Run the benchmark script
    system("ruby", script_path, @options[:host], @options[:port].to_s)
  end
end

if __FILE__ == $0
  runner = BenchmarkRunner.new
  runner.run
end
