# frozen_string_literal: true

require "fileutils"
require "openssl"

module RubyTAK
  class CLI
    module Commands
      class Certificate
        def initialize(args, options)
          @creator = ::RubyTAK::CertificateCreator.new

          case args.first
          when "ca" then @creator.create_ca_crt_and_key
          when "server" then @creator.create_crt_and_key(server: true)
          when "client" then @creator.create_crt_and_key(server: false, name: options.name || "client")
          when "all"
            @creator.create_ca_crt_and_key
            @creator.create_crt_and_key(server: true)
            @creator.create_crt_and_key(server: false, name: options.name || "client")
          else
            raise ArgumentError, "Unknown command: #{args.first}"
          end
        end
      end
    end
  end
end
