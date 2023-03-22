# frozen_string_literal: true

require "bundler/setup"
require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("ruby_tak" => "RubyTAK")
loader.inflector.inflect("cli" => "CLI")
loader.setup

require "ox"

module RubyTAK
  class Error < StandardError; end

  def configuration
    @configuration ||= Configuration.new
  end
  module_function :configuration

  def logger
    @logger ||= Logger.new($stdout)
  end
  module_function :logger

  def configure(path = nil)
    if path
      load(path)
    else
      yield(configuration)
    end
  end
  module_function :configure
end
