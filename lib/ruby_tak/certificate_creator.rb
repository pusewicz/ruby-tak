# frozen_string_literal: true

module RubyTAK
  class CertificateCreator
    def write_cert(crt_path, key_path, cert, key)
      if key_path.exist?
        puts "Key `#{key_path}' already exists, skipping"
      else
        puts "Creating key `#{key_path}'"
        File.write(key_path, key)
      end

      if crt_path.exist?
        puts "Certificate `#{crt_path}' already exists, skipping"
      else
        puts "Creating certificate `#{crt_path}'"
        File.write(crt_path, cert.to_pem)
      end
    end

    def write_p12(path, der)
      if path.exist?
        puts "PKCS12 `#{path}' already exists, skipping"
      else
        puts "Creating PKCS12 `#{path}'"
        File.write(path, der, binmode: true)
      end
    end

    def create_ca_crt_and_key
      private_key = OpenSSL::PKey::RSA.generate(2048, 65_537)
      now = Time.now

      root_ca = OpenSSL::X509::Certificate.new
      root_ca.version = 2
      root_ca.serial = OpenSSL::BN.new(Time.now.to_f.to_s) # TODO: Use a better serial number
      root_ca.subject = OpenSSL::X509::Name.parse("/CN=RubyTAK CA")
      root_ca.issuer = root_ca.subject
      root_ca.public_key = private_key.public_key
      root_ca.not_before = now
      root_ca.not_after = now + (2 * 365 * 24 * 60 * 60) # 2 years validity
      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = ef.issuer_certificate = root_ca
      root_ca.add_extension ef.create_extension("basicConstraints", "CA:TRUE", true)
      root_ca.add_extension ef.create_extension("subjectKeyIdentifier", "hash")
      root_ca.add_extension ef.create_extension("extendedKeyUsage", "serverAuth,clientAuth")
      root_ca.add_extension ef.create_extension("keyUsage", "keyCertSign,cRLSign,digitalSignature", true)

      signed = root_ca.sign(private_key, OpenSSL::Digest.new("SHA256"))

      write_cert(RubyTAK.configuration.ca_crt_path, RubyTAK.configuration.ca_key_path, signed, private_key)
    end

    def create_crt_and_key(server: true, name: nil) # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
      raise ArgumentError, "Name is required for client certificates" if !server && name.nil?

      private_key = OpenSSL::PKey::RSA.generate(2048, 65_537)
      now = Time.now
      ca_crt, ca_key = load_crt_and_key(RubyTAK.configuration.ca_crt_path, RubyTAK.configuration.ca_key_path)

      hostname = Socket.gethostname
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = OpenSSL::BN.new(Time.now.to_f.to_s) # TODO: Use a better serial number
      cert.subject = OpenSSL::X509::Name.new([["CN", name || hostname]])
      cert.issuer = ca_crt.subject
      cert.public_key = private_key.public_key
      cert.not_before = now
      cert.not_after = now + (2 * 365 * 24 * 60 * 60) # 2 years validity
      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = cert
      ef.issuer_certificate = ca_crt
      cert.add_extension ef.create_extension("basicConstraints", "CA:FALSE", true)
      cert.add_extension ef.create_extension("subjectKeyIdentifier", "hash")
      cert.add_extension ef.create_extension("authorityKeyIdentifier", "keyid:always,issuer:always")
      cert.add_extension ef.create_extension("extendedKeyUsage", server ? "serverAuth,clientAuth" : "clientAuth")
      # TODO: Move non-server stuff to a separate method
      key_usage = server ? "digitalSignature,keyEncipherment" : "digitalSignature,nonRepudiation,keyEncipherment"
      cert.add_extension ef.create_extension("keyUsage", key_usage, true)

      if server
        # TODO: Add SANs for the server by iterating over the names and IPs
        alt_names = ["DNS:#{hostname}"]
        Socket.ip_address_list.each do |ip|
          next unless ip.ipv4_private?

          alt_names << "IP:#{ip.ip_address}"
        end
        cert.add_extension ef.create_extension("subjectAltName", alt_names.join(","))
      end

      signed = cert.sign(ca_key, OpenSSL::Digest.new("SHA256"))
      # TODO: Server P12 should not contain the private key
      pkcs12 = OpenSSL::PKCS12.create("atakatak", name || hostname, private_key, signed, [ca_crt])

      if server
        write_cert(RubyTAK.configuration.server_crt_path, RubyTAK.configuration.server_key_path, signed,
                   private_key)
        write_p12(RubyTAK.configuration.server_p12_path, pkcs12.to_der)
      else
        write_cert(crt_path(name), key_path(name), signed,
                   private_key)
        write_p12(p12_path(name), pkcs12.to_der)
      end
    end

    def p12_path(name)
      RubyTAK.configuration.certs_dir.join("#{name}.p12")
    end

    def crt_path(name)
      RubyTAK.configuration.certs_dir.join("#{name}.crt")
    end

    def key_path(name)
      RubyTAK.configuration.certs_dir.join("#{name}.key")
    end

    def load_crt_and_key(crt_path, key_path)
      cert = OpenSSL::X509::Certificate.new(File.read(crt_path))
      key = OpenSSL::PKey::RSA.new(File.read(key_path))
      [cert, key]
    end
  end
end
