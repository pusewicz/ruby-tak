# frozen_string_literal: true

require "commander"

module RubyTAK
  class CLI
    include Commander::Methods

    def run
      program :name, "ruby_tak"
      program :version, RubyTAK::VERSION
      program :description, "RubyTAK—TAK server written in Ruby"
      default_command :server

      command :server do |s|
        s.syntax = "ruby_tak server"
        s.summary = "Start the RubyTAK server"
        s.action { |_args, _options| RubyTAK::Server.start }
      end

      command :certificate do |c|
        c.syntax = "ruby_tak certificate [options]"
        c.summary = "Manage certificates"
        c.description = "Allows for creating certificate authority and client certificates"
        c.example "description", "command example"
        c.when_called RubyTAK::CLI::Commands::Certificate
      end

      run!
    end
  end
end
