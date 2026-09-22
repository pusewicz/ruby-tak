# frozen_string_literal: true

require_relative "lib/ruby_tak/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_tak"
  spec.version = RubyTAK::VERSION
  spec.authors = ["Piotr Usewicz"]
  spec.email = ["piotr@layer22.com"]

  spec.summary = "Ruby TAK server"
  spec.description = "Ruby TAK server"
  spec.homepage = "https://github.com/pusewicz/ruby-tak"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/pusewicz/ruby-tak"
  spec.metadata["changelog_uri"] = "https://github.com/pusewicz/ruby-tak/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files =
    Dir.chdir(__dir__) do
      `git ls-files -z`.split("\x0").reject do |f|
        (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features|vendor)/|Steepfile\z|\.(?:git|circleci)|appveyor)})
      end
    end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "base64", "~> 0.2"
  spec.add_dependency "logger", "~> 1.7"
  spec.add_dependency "ox", "~> 2.14"
  spec.add_dependency "webrick", "~> 1.9"
  spec.add_dependency "xdg", "~> 10.0"
  spec.add_dependency "zeitwerk", "~> 2.8"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata["rubygems_mfa_required"] = "true"
end
