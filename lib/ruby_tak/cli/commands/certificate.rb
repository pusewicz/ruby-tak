# frozen_string_literal: true

require "fileutils"
require "certificate_authority"

module RubyTAK
  class CLI
    module Commands
      class Certificate
        def initialize(args, options)
          @args = args
          @options = options

          @ca_crt_path = RubyTAK.configuration.ca_crt_path
          @ca_key_path = RubyTAK.configuration.ca_key_path

          case args.first
          when "ca" then create_ca
          else
            raise ArgumentError, "Unknown command: #{args.first}"
          end
        end

        private

        def create_ca
          root = CertificateAuthority::Certificate.new
          root.subject.common_name = "RubyTAK CA"
          root.serial_number.number = 1
          root.key_material.generate_key
          root.signing_entity = true
          signing_profile = {
            "extensions" => {
              "basicConstraints" => { "ca" => true, "critical" => true },
              "keyUsage" => { "usage" => %w[critical keyCertSign] },
              "extendedKeyUsage" => { "usage" => %w[serverAuth clientAuth] }
            }
          }

          if @ca_crt_path.exist?
            puts "CA certificate `#{@ca_crt_path}' already exists, skipping"
          else
            puts "Creating CA certificate `#{@ca_crt_path}'"
            File.write(@ca_crt_path, root.sign!(signing_profile))
          end

          if @ca_key_path.exist?
            puts "CA key `#{@ca_key_path}' already exists, skipping"
          else
            puts "Creating CA key `#{@ca_key_path}'"
            File.write(@ca_key_path, root.key_material.private_key)
          end
        end
      end
    end
  end
end
