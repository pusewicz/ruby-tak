# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    RubyTAK.instance_variable_set(:@configuration, RubyTAK::Configuration.new)
  end

  def test_ca_crt_default
    assert_equal "ruby_tak-ca.crt", configuration.ca_crt
  end

  def test_ca_crt=
    configuration.ca_crt = "ca.crt"

    assert_equal "ca.crt", configuration.ca_crt
  end

  def test_ca_key_default
    assert_equal "ruby_tak-ca.key", configuration.ca_key
  end

  def test_ca_key=
    configuration.ca_key = "ca.key"

    assert_equal "ca.key", configuration.ca_key
  end

  def test_ca_crt_path
    assert_path_equal("certs/ruby_tak-ca.crt", configuration.ca_crt_path)
  end

  def test_cot_ssl_port_default
    assert_equal 8089, configuration.cot_ssl_port
  end

  def test_cot_ssl_port=
    configuration.cot_ssl_port = 1234

    assert_equal 1234, configuration.cot_ssl_port
  end

  def test_cot_ssl_port_range
    assert_raises(RubyTAK::Configuration::ArgumentError) { configuration.cot_ssl_port = 0 }
    assert_raises(RubyTAK::Configuration::ArgumentError) { configuration.cot_ssl_port = 65_536 }
  end

  def test_configure
    RubyTAK.configure do |conf|
      conf.cot_ssl_port = 1111
      conf.ca_crt = "ca.crt"
      conf.ca_key = "ca.key"
    end

    assert_equal 1111, configuration.cot_ssl_port
    assert_path_equal "certs/ca.crt", configuration.ca_crt_path
    assert_path_equal "certs/ca.key", configuration.ca_key_path
  end

  private

  def assert_path_equal(expected, actual)
    expected = Pathname.new(File.join(Dir.home, ".config/ruby_tak/", expected))

    assert_equal expected, actual, "Expected configuration setting #{actual} to equal #{expected}"
  end

  def configuration
    RubyTAK.configuration
  end
end
