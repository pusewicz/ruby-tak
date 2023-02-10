# frozen_string_literal: true

# TODO: Generate SSL certificate for localhost

# openssl req -x509 -newkey rsa:4096 -keyout certs/priv.pem -out certs/cert.pem -days 365 -nodes

require "bundler"
require "bundler/setup"
require "bundler/gem_tasks"

require "rake"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[test rubocop]

namespace :docker do
  desc "Build docker image"
  task :build do
    sh "docker build -t ruby-tak . --build-arg RUBY_VERSION=#{RUBY_VERSION}"
  end
end
