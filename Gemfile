# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gem "ox"
gem "xdg"
gem "zeitwerk"

group :development do
  gem "debug", require: false
  gem "overcommit", require: false
  gem "rake", require: false
  gem "rubocop", require: false
  gem "rubocop-minitest", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rake", require: false
end

group :test do
  gem "minitest"
  gem "simplecov", require: false
end
