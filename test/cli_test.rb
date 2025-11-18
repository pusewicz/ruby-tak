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
end
