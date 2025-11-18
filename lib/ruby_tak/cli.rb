# frozen_string_literal: true

require "optparse"

module RubyTAK
  class CLI
    def run(args = ARGV)
      options = {}

      subcommands = {
        "server" => OptionParser.new do |opts|
          opts.banner = "Usage: ruby_tak server [options]"

          opts.on("-p", "--port PORT", Integer, "Port to listen on") do |port|
            options[:port] = port
          end
        end,
        "certificate" => OptionParser.new do |opts|
          opts.banner = "Usage: ruby_tak certificate <ca|server> [options]"
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

      global.order!(args)
      command = args.shift
      subcommands[command]&.order!(args)

      case command
      when "server"
        RubyTAK.configuration.cot_ssl_port = options[:port] if options[:port]
        RubyTAK::Server.start
      when "certificate"
        cert_type = args.shift
        case cert_type
        when "ca"
          generate_ca_certificate
        when "server"
          generate_server_certificate
        else
          puts "Error: Unknown certificate type '#{cert_type}'"
          puts "Usage: ruby_tak certificate <ca|server>"
          exit 1
        end
      end
    end

    private

    def generate_ca_certificate
      require "openssl"

      config = RubyTAK.configuration
      ca_key_path = config.ca_key_path
      ca_crt_path = config.ca_crt_path

      if ca_key_path.exist? && ca_crt_path.exist?
        puts "CA certificate already exists at:"
        puts "  Key: #{ca_key_path}"
        puts "  Certificate: #{ca_crt_path}"
        puts "\nSkipping generation. Delete existing files to regenerate."
        return
      end

      puts "Generating CA certificate..."

      # Generate RSA key (2048-bit for TAK compatibility)
      key = OpenSSL::PKey::RSA.new(2048)

      # Create certificate
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 1
      cert.subject = OpenSSL::X509::Name.parse("/CN=RubyTAK CA/O=RubyTAK/C=US")
      cert.issuer = cert.subject # self-signed
      cert.public_key = key.public_key
      cert.not_before = Time.now
      cert.not_after = Time.now + (365 * 24 * 60 * 60 * 10) # 10 years (3652 days)

      # Add extensions for CA
      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = cert
      ef.issuer_certificate = cert
      cert.add_extension(ef.create_extension("basicConstraints", "CA:TRUE", true))
      cert.add_extension(ef.create_extension("keyUsage", "keyCertSign,cRLSign", true))
      cert.add_extension(ef.create_extension("subjectKeyIdentifier", "hash", false))
      cert.add_extension(ef.create_extension("authorityKeyIdentifier", "keyid:always", false))

      # Sign certificate
      cert.sign(key, OpenSSL::Digest.new("SHA256"))

      # Save PEM files
      File.write(ca_key_path, key.to_pem)
      File.chmod(0o600, ca_key_path)
      File.write(ca_crt_path, cert.to_pem)

      puts "CA certificate generated successfully:"
      puts "  Key: #{ca_key_path}"
      puts "  Certificate: #{ca_crt_path}"
    end

    def generate_server_certificate
      require "openssl"

      config = RubyTAK.configuration
      ca_key_path = config.ca_key_path
      ca_crt_path = config.ca_crt_path
      server_key_path = config.server_key_path
      server_crt_path = config.server_crt_path

      # Verify CA exists
      unless ca_key_path.exist? && ca_crt_path.exist?
        puts "Error: CA certificate not found. Generate CA first with:"
        puts "  ruby_tak certificate ca"
        exit 1
      end

      if server_key_path.exist? && server_crt_path.exist?
        puts "Server certificate already exists at:"
        puts "  Key: #{server_key_path}"
        puts "  Certificate: #{server_crt_path}"
        puts "\nSkipping generation. Delete existing files to regenerate."
        return
      end

      puts "Generating server certificate..."

      # Load CA certificate and key
      ca_key = OpenSSL::PKey::RSA.new(File.read(ca_key_path))
      ca_cert = OpenSSL::X509::Certificate.new(File.read(ca_crt_path))

      # Generate RSA key (2048-bit for TAK compatibility)
      server_key = OpenSSL::PKey::RSA.new(2048)

      # Create certificate
      server_cert = OpenSSL::X509::Certificate.new
      server_cert.version = 2
      server_cert.serial = OpenSSL::BN.rand(64).to_i # Random 64-bit serial
      server_cert.subject = OpenSSL::X509::Name.parse("/CN=#{config.hostname}/O=RubyTAK/C=US")
      server_cert.issuer = ca_cert.subject
      server_cert.public_key = server_key.public_key
      server_cert.not_before = Time.now
      server_cert.not_after = Time.now + (365 * 24 * 60 * 60 * 2) # 2 years (730 days)

      # Add extensions for server certificate
      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = server_cert
      ef.issuer_certificate = ca_cert
      server_cert.add_extension(ef.create_extension("basicConstraints", "CA:FALSE", true))
      server_cert.add_extension(ef.create_extension("keyUsage", "digitalSignature,keyEncipherment", true))
      server_cert.add_extension(
        ef.create_extension("extendedKeyUsage", "serverAuth,clientAuth", false)
      )
      server_cert.add_extension(ef.create_extension("subjectKeyIdentifier", "hash", false))
      server_cert.add_extension(ef.create_extension("authorityKeyIdentifier", "keyid:always", false))
      server_cert.add_extension(
        ef.create_extension("subjectAltName", "DNS:#{config.hostname},IP:127.0.0.1", false)
      )

      # Sign certificate with CA
      server_cert.sign(ca_key, OpenSSL::Digest.new("SHA256"))

      # Save PEM files
      File.write(server_key_path, server_key.to_pem)
      File.chmod(0o600, server_key_path)
      File.write(server_crt_path, server_cert.to_pem)

      puts "Server certificate generated successfully:"
      puts "  Key: #{server_key_path}"
      puts "  Certificate: #{server_crt_path}"
    end
  end
end
