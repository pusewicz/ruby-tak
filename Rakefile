# frozen_string_literal: true

# TODO: Generate SSL certificate for localhost

# openssl req -x509 -newkey rsa:4096 -keyout certs/priv.pem -out certs/cert.pem -days 365 -nodes

require "bundler"
require "bundler/setup"
require "bundler/gem_tasks"

require "English"
require "rake"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

# Stdlib signatures `sig/` depends on, plus the signature load paths. Shared by
# `rbs validate` and the `rbs/test` runtime verification pass. Keep in sync with
# the `library` list in Steepfile.
RBS_LIBRARIES = %w[base64 forwardable json logger openssl optparse pathname securerandom socket time timeout].freeze
RBS_SIGNATURE_DIRS = %w[sig vendor/sig].freeze
RBS_OPTS = [*RBS_LIBRARIES.map { |lib| "-r #{lib}" }, *RBS_SIGNATURE_DIRS.map { |dir| "-I #{dir}" }].join(" ").freeze

namespace :rbs do
  desc "Validate the RBS signatures"
  task :validate do
    sh "rbs #{RBS_OPTS} validate"
  end

  desc "Check that every lib/**/*.rb has a matching sig/**/*.rbs"
  task :complete do
    missing = Dir["lib/**/*.rb"].reject { |path| File.exist?(path.sub(%r{\Alib/}, "sig/").sub(/\.rb\z/, ".rbs")) }
    abort("Missing RBS signatures for:\n  #{missing.sort.join("\n  ")}") unless missing.empty?
  end
end

desc "Run the test suite with rbs/test runtime signature verification"
task "rbs:test" do
  env = {
    "RBS_TEST_TARGET" => "RubyTAK::*",
    "RBS_TEST_OPT" => RBS_OPTS,
    "RBS_TEST_DOUBLE_SUITE" => "minitest",
    "RBS_TEST_LOGLEVEL" => "info",
    "RUBYOPT" => "#{ENV.fetch("RUBYOPT", nil)} -rrbs/test/setup"
  }
  hooked = violation = false
  IO.popen(env, %w[rake test], err: %i[child out]) do |io|
    io.each_line do |line|
      hooked ||= line.include?("Setting up hooks for ::RubyTAK")
      violation ||= line.include?("RBS::Test::Tester::TypeError")
      $stdout.print(line)
    end
  end
  abort("rbs/test: test suite failed") unless $CHILD_STATUS.success?
  # A non-matching RBS_TEST_TARGET installs no hooks and still exits 0 — fail loudly instead.
  abort("rbs/test: no signatures were instrumented") unless hooked
  # Violations raised inside worker threads only reach stderr, so scan for them too.
  abort("rbs/test: runtime signature violation detected") if violation
end

desc "Type check lib/ and exe/ with Steep"
task :steep do
  sh "steep check"
end

task default: %i[test rubocop rbs:validate rbs:complete steep rbs:test]

namespace :docker do
  desc "Build docker image"
  task :build do
    sh "docker build -t ruby-tak . --build-arg RUBY_VERSION=#{RUBY_VERSION}"
  end
end
