# frozen_string_literal: true

require "openssl"

module RubyTAK
  class CertificateAuthority
    class InvalidCSR < RubyTAK::Error; end

    VALIDITY_DAYS = 365

    def initialize(config: RubyTAK.configuration)
      @config = config
    end

    def certificate
      @certificate ||= OpenSSL::X509::Certificate.new(File.read(@config.ca_crt_path))
    end

    def sign_client_csr(csr_pem, validity_days: VALIDITY_DAYS)
      request = parse_csr(csr_pem)
      raise InvalidCSR, "CSR signature verification failed" unless request.verify(request.public_key)

      ca_key = OpenSSL::PKey::RSA.new(File.read(@config.ca_key_path))

      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = OpenSSL::BN.rand(64).to_i
      cert.subject = request.subject
      cert.issuer = certificate.subject
      cert.public_key = request.public_key
      cert.not_before = Time.now
      cert.not_after = Time.now + (validity_days * 24 * 60 * 60)

      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = cert
      ef.issuer_certificate = certificate
      cert.add_extension(ef.create_extension("basicConstraints", "CA:FALSE", true))
      cert.add_extension(ef.create_extension("keyUsage", "digitalSignature,keyEncipherment", true))
      cert.add_extension(ef.create_extension("extendedKeyUsage", "clientAuth", false))
      cert.add_extension(ef.create_extension("subjectKeyIdentifier", "hash", false))
      cert.add_extension(ef.create_extension("authorityKeyIdentifier", "keyid:always", false))

      cert.sign(ca_key, OpenSSL::Digest.new("SHA256"))
      cert
    end

    private

    def parse_csr(csr_pem)
      text = csr_pem.to_s.strip
      text = "-----BEGIN CERTIFICATE REQUEST-----\n#{text}\n-----END CERTIFICATE REQUEST-----\n" unless text.include?("BEGIN CERTIFICATE REQUEST")
      OpenSSL::X509::Request.new(text)
    rescue OpenSSL::X509::RequestError => e
      raise InvalidCSR, e.message
    end
  end
end
