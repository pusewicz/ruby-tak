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

      command :certificate do |s|
        s.syntax = "ruby_tak certificate ca|server|client"
        s.summary = "Generate certificates for CA, Server or Client"
        s.option "--name [NAME]", String, "Name of the client certificate"
        s.when_called Commands::Certificate
      end

      command :client do |s|
        s.syntax = "ruby_tak client"
        s.summary = "Generate client package"
        s.option "--name NAME", String, "Name of the client"
        s.when_called Commands::Client
      end

      run!
    end
  end
end
