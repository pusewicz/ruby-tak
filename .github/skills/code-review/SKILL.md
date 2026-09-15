---
name: code-review
description: Review Ruby changes in RubyTAK for test coverage, exception handling, and thread-safety conventions specific to this codebase.
---

# RubyTAK Code Review

Flag these issues when reviewing a pull request in this repository.

## Test coverage

- CI enforces 100% line coverage (`minimum_coverage 100 if ENV["CI"]` in `test/test_helper.rb`). Any changed line without a covering test should fail review.
- Tests should use predicate assertions (`assert_predicate obj, :exist?` not `assert obj.exist?`).
- Flag tests with more than 3 assertions — they should be split.
- File-system tests must use `Dir.mktmpdir`, not real paths.
- Tests must stub servers/network calls (e.g. `RubyTAK::Server.stub :start, nil`), never start real listeners or make network calls.

## Exception handling

- Flag redundant rescues where one class is a subclass of another already rescued (e.g. `rescue EOFError, IOError` — `EOFError < IOError`).
- Normal conditions (client disconnects: `IOError`, `Errno::EBADF`) should not be counted as errors/increment error stats; only `StandardError` should.

## Thread safety

- Shared collections (`@clients`, etc.) must only be accessed inside `@clients_mutex.synchronize`.
- Flag multiple separate `synchronize` blocks that could be combined into one to avoid races between the read and the write.
- Before iterating a shared collection, it must be copied out under the mutex first (`@clients_mutex.synchronize { @clients.to_a }`), never iterated live.

## Style

- Arrays of strings should use `%w[]`, not `["a", "b"]`.
- Non-decimal numeric literals need explicit prefixes (`0o600`, not `0600`).
- Ruby files must start with `# frozen_string_literal: true`.
- Strings use double quotes.

## Other

- `OptionParser#order!` must be called with an explicit `args` argument — bare `order!` defaults to `ARGV` and breaks in tests/non-CLI contexts.
- Setters for config values (e.g. `port=`) should validate and raise `ArgumentError` on bad input.
- `OpenSSL::PKCS12.create` must not rely on the SHA256 MAC default — TAK/ATAK compatibility requires the system `openssl` command instead.
