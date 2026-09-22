# frozen_string_literal: true

target :lib do
  signature "sig", "vendor/sig"

  check "lib"
  check "exe/ruby_tak"

  library(
    "base64",
    "forwardable",
    "json",
    "logger",
    "openssl",
    "optparse",
    "pathname",
    "securerandom",
    "socket",
    "time",
    "timeout"
  )

  configure_code_diagnostics(Steep::Diagnostic::Ruby.strict)
end
