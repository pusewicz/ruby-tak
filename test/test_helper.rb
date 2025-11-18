# frozen_string_literal: true

require "simplecov"
SimpleCov.start

$LOAD_PATH.unshift(File.expand_path("lib", __dir__))

require "bundler/setup"
require "ruby_tak"
require "minitest/autorun"
require "debug"
