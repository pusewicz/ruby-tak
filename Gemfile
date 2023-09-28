# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gem "ox", "~> 2.14.16"
gem "xdg", "~> 7.1"
gem "zeitwerk", "~> 2.6.11"

group :development do
  gem "debug", "~> 1.8"
  gem "rake", "~> 13.0", require: false
  gem "rubocop", "~> 1.56.4", require: false
  gem "rubocop-minitest", "~> 0.32.2"
  gem "rubocop-performance", "~> 1.19.0", require: false
  gem "rubocop-rake", "~> 0.6.0"
  gem "rubocop-thread_safety", "~> 0.5.1", require: false
  gem "solargraph", "~> 0.49.0", require: false
end

group :test do
  gem "minitest", "~> 5.20"
end
