# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gem "ox", "~> 2.14.18"
gem "xdg", "~> 7.1"
gem "zeitwerk", "~> 2.7.1"

group :development do
  gem "debug", "~> 1.9"
  gem "overcommit", require: false
  gem "rake", "~> 13.2", require: false
  gem "rubocop", "~> 1.68.0", require: false
  gem "rubocop-minitest", "~> 0.36.0"
  gem "rubocop-performance", "~> 1.22.1", require: false
  gem "rubocop-rake", "~> 0.6.0"
  gem "rubocop-thread_safety", "~> 0.5.1", require: false
  gem "solargraph", "~> 0.50.0", require: false
end

group :test do
  gem "minitest", "~> 5.25"
end
