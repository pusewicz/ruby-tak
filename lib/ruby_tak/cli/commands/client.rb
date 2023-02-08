# frozen_string_literal: true

require "fileutils"
require "securerandom"
require "zip"

module RubyTAK
  class CLI
    module Commands
      class Client
        def initialize(_args, options)
          # TODO: Use commander's highline support to ask for name
          @name = options.name || "client"

          @file_prefix = "#{@name}-#{SecureRandom.uuid}"

          @creator = ::RubyTAK::CertificateCreator.new

          @config = RubyTAK.configuration

          create_client
        end

        private

        def create_client
          Dir.mktmpdir(["client", @name]) do |dir| # rubocop:disable Metrics/BlockLength
            # Copy server p12
            target_server_p12_path = File.join(dir, "#{@file_prefix}-server.p12")
            puts "Copying server p12 to #{target_server_p12_path}"
            FileUtils.cp(@config.server_p12_path, target_server_p12_path)

            # Create client certificate
            @creator.create_crt_and_key(server: false, name: @name)

            # Copy client p12
            target_client_p12_path = File.join(dir, "#{@file_prefix}-client.p12")
            puts "Copying client p12 to #{target_client_p12_path}"
            FileUtils.cp(@creator.p12_path(@name), target_client_p12_path)

            # Copy client crt
            target_client_crt_path = File.join(dir, "#{@file_prefix}-client.crt")
            puts "Copying client crt to #{target_client_crt_path}"
            FileUtils.cp(@creator.crt_path(@name), target_client_crt_path)

            # Copy client key
            target_client_key_path = File.join(dir, "#{@file_prefix}-client.key")
            puts "Copying client key to #{target_client_key_path}"
            FileUtils.cp(@creator.key_path(@name), target_client_key_path)

            # Create client prefs
            pref_builder = ::RubyTAK::ClientPrefsBuilder.new(
              cot_streams: {
                count: 1,
                description0: @config.hostname,
                enabled0: false,
                connectString0: "#{@config.hostname}:#{@config.cot_ssl_port}:ssl"
              },
              "com.atakmap.app_preferences": {
                caLocation: File.basename(target_server_p12_path),
                caPassword: "atakatak",
                clientPassword: "atakatak",
                certificateLocation: File.basename(target_client_p12_path)
              }
            )

            preference_path = File.join(dir, "preference.pref")
            puts "Writing client prefs to #{preference_path}"
            File.write(preference_path, pref_builder.to_xml)

            # Create zip
            zip_path = File.join(Dir.pwd, "#{@name}.zip")
            if File.exist?(zip_path)
              puts "Zip already exists at #{zip_path}"
            else
              puts "Creating zip at #{zip_path}"
              Zip::File.open(zip_path, Zip::File::CREATE) do |zipfile|
                zipfile.add(File.basename(target_server_p12_path), target_server_p12_path)
                zipfile.add(File.basename(target_client_p12_path), target_client_p12_path)
                zipfile.add(File.basename(preference_path), preference_path)
              end
            end
          end
        end
      end
    end
  end
end
