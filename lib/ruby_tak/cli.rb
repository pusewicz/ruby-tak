# frozen_string_literal: true

require "optparse"

module RubyTAK
  class CLI
    def run(args = ARGV)
      subcommands = {
        "server" => OptionParser.new do |opts|
          opts.banner = "Usage: ruby_tak server [options]"

          opts.on("-p", "--port PORT", "Port to listen on") do |port|
            puts port
          end
        end
      }

      global = OptionParser.new do |opts|
        opts.banner = "Usage: ruby_tak [options]"

        opts.on("-v", "--version", "Print version") do
          puts RubyTAK::VERSION
          exit
        end

        opts.on("-h", "--help", "Print help") do
          puts opts

          puts "\nSubcommands:"
          subcommands.each do |name, subcommand|
            puts "  #{name}\t#{subcommand.banner}"
          end

          exit
        end
      end

      args.unshift("-h") if args.empty?

      global.order!
      command = args.shift
      subcommands[command]&.order!

      case command
      when "server"
        RubyTAK::Server.start
      end
    end
  end
end
