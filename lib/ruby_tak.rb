# frozen_string_literal: true

require "bundler/setup"
require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("ruby_tak" => "RubyTAK")
loader.setup

require "ox"

module RubyTAK
  class Error < StandardError; end
end
