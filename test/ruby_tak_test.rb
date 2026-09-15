# frozen_string_literal: true

require "test_helper"

class RubyTAKTest < Minitest::Test
  def setup
    RubyTAK.instance_variable_set(:@configuration, RubyTAK::Configuration.new)
  end

  def test_that_it_has_a_version_number
    refute_nil(::RubyTAK::VERSION)
  end

  def test_logger_returns_a_logger_instance
    assert_instance_of Logger, RubyTAK.logger
  end

  def test_configure_with_path_loads_file
    Dir.mktmpdir do |tmpdir|
      config_file = File.join(tmpdir, "config.rb")
      File.write(config_file, "RubyTAK.configuration.cot_ssl_port = 1234")

      RubyTAK.configure(config_file)

      assert_equal 1234, RubyTAK.configuration.cot_ssl_port
    end
  end
end
