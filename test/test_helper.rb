# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("lib", __dir__))

require "bundler/setup"
require "ruby_tak"
require "minitest/autorun"
require "minitest/reporters"
require "debug"

Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new(color: true)]
