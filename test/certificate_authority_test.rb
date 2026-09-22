# frozen_string_literal: true

require "test_helper"
require "openssl"

class CertificateAuthorityTest < Minitest::Test
  def setup
    RubyTAK.instance_variable_set(:@configuration, RubyTAK::Configuration.new)
  end

  def test_sign_client_csr_returns_a_cert_verifiable_by_the_ca
    with_ca do |ca, ca_cert|
      csr = build_csr("test-client")

      signed = ca.sign_client_csr(csr.to_pem)

      assert signed.verify(ca_cert.public_key)
    end
  end

  def test_sign_client_csr_sets_client_auth_extended_key_usage
    with_ca do |ca, _ca_cert|
      csr = build_csr("test-client")

      signed = ca.sign_client_csr(csr.to_pem)
      eku = signed.extensions.find { |ext| ext.oid == "extendedKeyUsage" }

      assert_match(/TLS Web Client Authentication/, eku.value)
    end
  end

  def test_sign_client_csr_raises_for_a_csr_with_an_invalid_signature
    with_ca do |ca, _ca_cert|
      csr = build_csr("test-client")
      tampered = OpenSSL::X509::Request.new(csr.to_der)
      tampered.subject = OpenSSL::X509::Name.parse("/CN=tampered")

      assert_raises(RubyTAK::CertificateAuthority::InvalidCSR) { ca.sign_client_csr(tampered.to_pem) }
    end
  end

  private

  def build_csr(common_name)
    key = OpenSSL::PKey::RSA.new(2048)
    csr = OpenSSL::X509::Request.new
    csr.version = 0
    csr.subject = OpenSSL::X509::Name.parse("/CN=#{common_name}/O=RubyTAK/C=US")
    csr.public_key = key.public_key
    csr.sign(key, OpenSSL::Digest.new("SHA256"))
    csr
  end

  def with_ca
    Dir.mktmpdir do |tmpdir|
      config = RubyTAK.configuration
      config.stub :certs_dir, Pathname.new(tmpdir) do
        capture_io { RubyTAK::CLI.new.run(%w[certificate ca]) }

        ca_cert = OpenSSL::X509::Certificate.new(File.read(config.ca_crt_path))
        yield RubyTAK::CertificateAuthority.new(config: config), ca_cert
      end
    end
  end
end
