# frozen_string_literal: true

require "test_helper"

class CLITest < Minitest::Test
  def setup
    @cli = RubyTAK::CLI.new
    RubyTAK.instance_variable_set(:@configuration, RubyTAK::Configuration.new)
  end

  def test_port_option_sets_configuration
    # Mock Server.start to avoid actually starting the server
    RubyTAK::Server.stub :start, nil do
      @cli.run(["server", "--port", "9999"])

      assert_equal 9999, RubyTAK.configuration.cot_ssl_port
    end
  end

  def test_port_option_short_form
    RubyTAK::Server.stub :start, nil do
      @cli.run(["server", "-p", "7777"])

      assert_equal 7777, RubyTAK.configuration.cot_ssl_port
    end
  end

  def test_port_option_validates_integer
    RubyTAK::Server.stub :start, nil do
      assert_raises(OptionParser::InvalidArgument) do
        @cli.run(["server", "--port", "invalid"])
      end
    end
  end

  def test_server_without_port_uses_default
    RubyTAK::Server.stub :start, nil do
      @cli.run(["server"])

      assert_equal 8089, RubyTAK.configuration.cot_ssl_port
    end
  end

  def test_certificate_ca_generates_files
    Dir.mktmpdir do |tmpdir|
      config = RubyTAK.configuration
      config.stub :certs_dir, Pathname.new(tmpdir) do
        ca_key_path = Pathname.new(tmpdir).join(config.ca_key)
        ca_crt_path = Pathname.new(tmpdir).join(config.ca_crt)

        capture_io do
          @cli.run(%w[certificate ca])
        end

        assert_predicate ca_key_path, :exist?, "CA key file should exist"
        assert_predicate ca_crt_path, :exist?, "CA certificate file should exist"

        # Verify key permissions
        assert_equal 0o100600, ca_key_path.stat.mode
      end
    end
  end

  def test_certificate_ca_generates_valid_x509
    Dir.mktmpdir do |tmpdir|
      config = RubyTAK.configuration
      config.stub :certs_dir, Pathname.new(tmpdir) do
        ca_crt_path = Pathname.new(tmpdir).join(config.ca_crt)

        capture_io do
          @cli.run(%w[certificate ca])
        end

        # Verify certificate is valid X.509
        cert = OpenSSL::X509::Certificate.new(File.read(ca_crt_path))

        assert_equal "RubyTAK CA", cert.subject.to_a.find { |attr| attr[0] == "CN" }[1]
      end
    end
  end

  def test_certificate_ca_skips_if_exists
    Dir.mktmpdir do |tmpdir|
      config = RubyTAK.configuration
      config.stub :certs_dir, Pathname.new(tmpdir) do
        # Generate once
        capture_io { @cli.run(%w[certificate ca]) }

        # Try to generate again
        output = capture_io do
          @cli.run(%w[certificate ca])
        end

        assert_match(/already exists/, output[0])
        assert_match(/Skipping generation/, output[0])
      end
    end
  end

  def test_certificate_invalid_type_shows_error
    error = nil
    output = capture_io do
      error = assert_raises(SystemExit) do
        @cli.run(%w[certificate invalid])
      end
    end

    assert_equal 1, error.status
    assert_match(/Unknown certificate type 'invalid'/, output[0])
  end

  def test_certificate_server_requires_ca
    Dir.mktmpdir do |tmpdir|
      config = RubyTAK.configuration
      config.stub :certs_dir, Pathname.new(tmpdir) do
        error = nil
        output = capture_io do
          error = assert_raises(SystemExit) do
            @cli.run(%w[certificate server])
          end
        end

        assert_equal 1, error.status
        assert_match(/CA certificate not found/, output[0])
      end
    end
  end

  def test_certificate_server_generates_files
    Dir.mktmpdir do |tmpdir|
      config = RubyTAK.configuration
      config.stub :certs_dir, Pathname.new(tmpdir) do
        # Generate CA first
        capture_io { @cli.run(%w[certificate ca]) }

        server_key_path = Pathname.new(tmpdir).join(config.server_key)
        server_crt_path = Pathname.new(tmpdir).join(config.server_crt)

        capture_io do
          @cli.run(%w[certificate server])
        end

        assert_predicate server_key_path, :exist?
        assert_predicate server_crt_path, :exist?
        assert_equal 0o100600, server_key_path.stat.mode
      end
    end
  end

  def test_certificate_server_generates_valid_x509
    Dir.mktmpdir do |tmpdir|
      config = RubyTAK.configuration
      config.stub :certs_dir, Pathname.new(tmpdir) do
        # Generate CA first
        capture_io { @cli.run(%w[certificate ca]) }

        server_crt_path = Pathname.new(tmpdir).join(config.server_crt)

        capture_io do
          @cli.run(%w[certificate server])
        end

        # Verify certificate is valid X.509
        cert = OpenSSL::X509::Certificate.new(File.read(server_crt_path))

        assert_equal config.hostname, cert.subject.to_a.find { |attr| attr[0] == "CN" }[1]
      end
    end
  end

  def test_certificate_server_signed_by_ca
    Dir.mktmpdir do |tmpdir|
      config = RubyTAK.configuration
      config.stub :certs_dir, Pathname.new(tmpdir) do
        # Generate CA first
        capture_io { @cli.run(%w[certificate ca]) }

        ca_crt_path = Pathname.new(tmpdir).join(config.ca_crt)
        server_crt_path = Pathname.new(tmpdir).join(config.server_crt)

        capture_io do
          @cli.run(%w[certificate server])
        end

        # Verify certificate chain
        ca_cert = OpenSSL::X509::Certificate.new(File.read(ca_crt_path))
        server_cert = OpenSSL::X509::Certificate.new(File.read(server_crt_path))

        assert_equal ca_cert.subject.to_s, server_cert.issuer.to_s
      end
    end
  end

  def test_certificate_server_skips_if_exists
    Dir.mktmpdir do |tmpdir|
      config = RubyTAK.configuration
      config.stub :certs_dir, Pathname.new(tmpdir) do
        # Generate CA first
        capture_io { @cli.run(%w[certificate ca]) }

        # Generate once
        capture_io { @cli.run(%w[certificate server]) }

        # Try to generate again
        output = capture_io do
          @cli.run(%w[certificate server])
        end

        assert_match(/already exists/, output[0])
      end
    end
  end
end
