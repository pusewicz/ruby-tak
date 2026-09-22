# frozen_string_literal: true

require "base64"
require "json"
require "openssl"
require "webrick"
require "webrick/https"

module RubyTAK
  class EnrollmentServer
    # IO-like adapter so WEBrick can log through RubyTAK's own logger.
    class LoggerIO
      def initialize(logger)
        @logger = logger
      end

      def <<(message)
        @logger.info(message.to_s.chomp)
        self
      end
    end

    attr_reader :logger

    def initialize(logger: RubyTAK.logger, certificate_authority: CertificateAuthority.new)
      @logger = logger
      @certificate_authority = certificate_authority
    end

    def start
      config = RubyTAK.configuration
      server = WEBrick::HTTPServer.new(
        Port: config.cert_enrollment_port,
        BindAddress: "0.0.0.0",
        SSLEnable: true,
        SSLCertificate: OpenSSL::X509::Certificate.new(File.read(config.server_crt_path)),
        SSLPrivateKey: OpenSSL::PKey::RSA.new(File.read(config.server_key_path)),
        Logger: WEBrick::Log.new(LoggerIO.new(logger), WEBrick::Log::WARN),
        AccessLog: []
      )
      server.mount_proc("/Marti/api/tls/config") { |req, res| with_auth(req, res) { tls_config(req, res) } }
      server.mount_proc("/Marti/api/tls/signClient/v2") { |req, res| with_auth(req, res) { sign_client(req, res) } }
      server.mount_proc("/Marti/api/tls/profile/enrollment") { |req, res| with_auth(req, res) { res.status = 204 } }
      server.mount_proc("/") { |req, res| handle_unknown(req, res) }
      logger.info("Starting #{self.class.name} on port #{config.cert_enrollment_port}")
      @server = server
      server.start
    end

    def shutdown
      @server&.shutdown
    end

    private

    def with_auth(req, res)
      logger.info("ENROLL: #{req.request_method} #{req.path}?#{req.query_string} accept=#{req["Accept"].inspect}")

      encoded = req["Authorization"].to_s.delete_prefix("Basic ")
      username, password = Base64.decode64(encoded).split(":", 2)

      unless Users.authenticate?(username, password)
        logger.warn("ENROLL: AUTH FAILED #{username.inspect}")
        res.status = 401
        return
      end

      yield
    end

    def tls_config(_req, res)
      res.content_type = "application/xml"
      res.body = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <certificateConfig validityDays="#{CertificateAuthority::VALIDITY_DAYS}"><nameEntries><nameEntry name="O" value="RubyTAK"/><nameEntry name="OU" value="RubyTAK"/></nameEntries></certificateConfig>
      XML
    end

    def sign_client(req, res)
      logger.debug("ENROLL: signClient/v2 content-type=#{req.content_type.inspect} body=#{req.body.inspect}")

      signed_cert = @certificate_authority.sign_client_csr(req.body)
      signed_cert_der = Base64.strict_encode64(signed_cert.to_der)
      ca_der = Base64.strict_encode64(@certificate_authority.certificate.to_der)
      json = { signedCert: signed_cert_der, ca0: ca_der, ca1: ca_der }.to_json

      case req["Accept"]
      when "text/plain"
        res.content_type = "text/plain"
        res.body = json
      when nil, "", "application/json", "*/*"
        res.content_type = "application/json"
        res.body = json
      else
        res.content_type = "application/xml"
        res.body = <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <enrollment><signedCert>#{signed_cert_der}</signedCert><ca>#{ca_der}</ca></enrollment>
        XML
      end
    rescue CertificateAuthority::InvalidCSR => e
      logger.warn("ENROLL: signClient/v2 rejected CSR: #{e.message}")
      res.status = 400
    end

    def handle_unknown(req, res)
      logger.info(
        "ENROLL: #{req.request_method} #{req.path}?#{req.query_string} " \
        "headers=#{redact_authorization(req.header.to_h)} body=#{req.body.inspect}"
      )
      res.status = 404
    end

    def redact_authorization(headers)
      return headers unless headers.key?("authorization")

      headers.merge("authorization" => ["[REDACTED]"])
    end
  end
end
