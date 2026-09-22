# frozen_string_literal: true

require "test_helper"
require "base64"
require "json"
require "net/http"
require "openssl"
require "stringio"

class EnrollmentServerTest < Minitest::Test
  def setup
    @log_output = StringIO.new
    @logger = Logger.new(@log_output)
    @logger.level = Logger::INFO
  end

  def test_logger_io_forwards_messages_to_the_logger
    RubyTAK::EnrollmentServer::LoggerIO.new(@logger) << "webrick message\n"

    assert_match(/webrick message/, @log_output.string)
  end

  def test_unknown_path_logs_request_and_responds_not_found
    with_enrollment_server do |_server, port|
      response = get(port, "/nonexistent")

      assert_equal "404", response.code
      assert_match(%r{ENROLL: GET /nonexistent}, @log_output.string)
    end
  end

  def test_unknown_path_redacts_the_authorization_header
    with_enrollment_server do |_server, port|
      get(port, "/nonexistent")

      assert_match(/"authorization" => \["\[REDACTED\]"\]/, @log_output.string)
      refute_includes @log_output.string, Base64.strict_encode64("piotr:password")
    end
  end

  def test_tls_config_returns_certificate_config_xml
    with_enrollment_server do |_server, port|
      response = get(port, "/Marti/api/tls/config")

      assert_equal "200", response.code
      assert_includes(response.body, %(validityDays="#{RubyTAK::CertificateAuthority::VALIDITY_DAYS}"))
    end
  end

  def test_profile_enrollment_returns_no_content
    with_enrollment_server do |_server, port|
      response = get(port, "/Marti/api/tls/profile/enrollment")

      assert_equal "204", response.code
    end
  end

  def test_authenticated_routes_reject_bad_credentials
    with_enrollment_server do |_server, port|
      response = get(port, "/Marti/api/tls/config", username: "piotr", password: "wrong")

      assert_equal "401", response.code
    end
  end

  def test_authenticated_routes_reject_missing_authorization_header
    with_enrollment_server do |_server, port|
      response = get(port, "/Marti/api/tls/config", username: nil, password: nil)

      assert_equal "401", response.code
    end
  end

  def test_sign_client_v2_returns_a_cert_verifiable_by_the_ca
    with_enrollment_server do |server, port|
      csr = build_csr("test-client")

      response = post(port, "/Marti/api/tls/signClient/v2?clientUid=test&version=2.12.3", csr.to_pem)
      body = JSON.parse(response.body)
      signed_cert = OpenSSL::X509::Certificate.new(Base64.strict_decode64(body["signedCert"]))
      ca_cert = server.instance_variable_get(:@certificate_authority).certificate

      assert_equal "200", response.code
      assert_equal "application/json", response.content_type
      assert signed_cert.verify(ca_cert.public_key)
      assert_equal body["ca0"], body["ca1"]
    end
  end

  def test_sign_client_v2_returns_json_body_with_text_plain_content_type_for_itak
    with_enrollment_server do |_server, port|
      csr = build_csr("test-client")

      response = post(port, "/Marti/api/tls/signClient/v2?clientUid=test&version=2.12.3", csr.to_pem,
                      accept: "text/plain")
      body = JSON.parse(response.body)

      assert_equal "200", response.code
      assert_equal "text/plain", response.content_type
      assert body.key?("signedCert")
    end
  end

  def test_sign_client_v2_returns_xml_body_when_accept_requests_it
    with_enrollment_server do |_server, port|
      csr = build_csr("test-client")

      response = post(port, "/Marti/api/tls/signClient/v2?clientUid=test&version=2.12.3", csr.to_pem,
                      accept: "application/xml")

      assert_equal "200", response.code
      assert_equal "application/xml", response.content_type
      assert_match(%r{<enrollment><signedCert>.+</signedCert><ca>.+</ca></enrollment>}, response.body)
    end
  end

  def test_sign_client_v2_rejects_an_invalid_csr
    with_enrollment_server do |_server, port|
      response = post(port, "/Marti/api/tls/signClient/v2?clientUid=test&version=2.12.3", "not a csr")

      assert_equal "400", response.code
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

  def get(port, path, username: "piotr", password: "password")
    uri = URI("https://127.0.0.1:#{port}#{path}")
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      request = Net::HTTP::Get.new(uri)
      request.basic_auth(username, password) if username
      http.request(request)
    end
  end

  def post(port, path, body, accept: nil)
    uri = URI("https://127.0.0.1:#{port}#{path}")
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      request = Net::HTTP::Post.new(uri)
      request.basic_auth("piotr", "password")
      request["Accept"] = accept if accept
      request.body = body
      http.request(request)
    end
  end

  def with_enrollment_server
    Dir.mktmpdir do |tmpdir|
      config = RubyTAK.configuration
      config.stub :certs_dir, Pathname.new(tmpdir) do
        capture_io { RubyTAK::CLI.new.run(%w[certificate ca]) }
        capture_io { RubyTAK::CLI.new.run(%w[certificate server]) }

        config.stub :cert_enrollment_port, 0 do
          server = RubyTAK::EnrollmentServer.new(logger: @logger)
          server_thread = Thread.new { server.start }
          server_thread.report_on_exception = false
          sleep 0.2

          webrick_server = server.instance_variable_get(:@server)
          port = webrick_server.listeners.first.addr[1]

          begin
            yield server, port
          ensure
            server.shutdown
            server_thread.join(1)
          end
        end
      end
    end
  end
end
