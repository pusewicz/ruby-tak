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

      run!
    end
  end
end
