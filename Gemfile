# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Optimized XML parser
gem "ox", "~> 2.14.0"
# Zeitwerk is a modern code loader for Ruby
gem "zeitwerk", "~> 2.6.7"

gem "commander", "~> 4.6"
gem "rubyzip", "~> 2.3"
gem "xdg", "~> 7.0"

group :development do
  # Code formatter
  gem "rubocop", "~> 1.48.1", require: false
  # Performance cops for RuboCop
  gem "rubocop-performance", "~> 1.16.0", require: false
  # Thread safety cops for RuboCop
  gem "rubocop-thread_safety", "~> 0.4.4", require: false
  # Minitest plugin for RuboCop
  gem "rubocop-minitest", "~> 0.29.0"
  # Rake plugin for RuboCop
  gem "rubocop-rake", "~> 0.6.0"
  # Ruby LSP server
  gem "solargraph", "~> 0.48.0", require: false
  # Rake tasks
  gem "rake", "~> 13.0", require: false

  gem "debug", "~> 1.7"
  gem "minitest-reporters", "~> 1.6"
end

group :test do
  # Unit testing framework
  gem "minitest", "~> 5.18"
end
