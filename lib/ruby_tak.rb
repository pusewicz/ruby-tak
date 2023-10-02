# frozen_string_literal: true

require "bundler/setup"
require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("ruby_tak" => "RubyTAK")
loader.inflector.inflect("cli" => "CLI")
loader.setup

require "ox"
require "logger"

module RubyTAK
  class Error < StandardError; end

  @mutex = Mutex.new

  def configuration
    @mutex.synchronize do
      @configuration ||= Configuration.new
    end
  end
  module_function :configuration

  def logger
    $stdout.sync = true
    @mutex.synchronize do
      @logger ||= Logger.new($stdout, level: ENV["DEBUG"] ? Logger::DEBUG : Logger::INFO)
    end
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
