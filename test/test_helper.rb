# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  minimum_coverage 100 if ENV["CI"]
end

$LOAD_PATH.unshift(File.expand_path("lib", __dir__))

require "bundler/setup"
require "ruby_tak"
require "minitest/autorun"
require "minitest/mock"
require "debug"
