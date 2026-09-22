# Certificate Enrollment API — Implementation Plan

**Goal:** Make iTAK's "TAK Server" (username/password) connection type
work against RubyTAK by implementing the certificate-enrollment REST
API it calls on port 8446 before ever opening the CoT socket.

**Architecture:** A new `RubyTAK::EnrollmentServer` runs a
`WEBrick::HTTPServer` on `config.cert_enrollment_port` (8446),
started/stopped alongside the existing CoT `TCPServer` by
`RubyTAK::Server`. A new `RubyTAK::CertificateAuthority` signs client
CSRs against the existing CA. Credentials move to a shared
`RubyTAK::Users` module.

**Tech Stack:** `webrick` (new runtime dependency), Ruby stdlib
`openssl`/`base64`/`json`, existing Minitest/SimpleCov setup.

**Spec:** `docs/superpowers/specs/2026-09-22-cert-enrollment-design.md`

## Global Constraints

- CI requires 100% line coverage — every new branch needs a test.
- Run `./bin/rake` (tests + rubocop) before considering any task done.
- Work happens in a git worktree, per this repo's CLAUDE.md.
- `%w[]` for string arrays, `0o` prefix for octal literals,
  `assert_predicate` over `assert x.exist?`, ≤3 assertions per test
  (rubocop's hard cap is 5).
- Don't bundle unrelated refactoring into a task (e.g. extracting
  `CertificateAuthority` must not touch the CLI's existing cert
  generation code).

---

## Task 0: De-risk `webrick` before building anything on top of it

**Files:** `ruby-tak.gemspec` (add dependency)

`lib/ruby_tak.rb` calls `require "bundler/setup"`, which prunes
`$LOAD_PATH` to declared gems — a globally-installed `webrick` is
invisible under `bundle exec` even though it loads fine standalone.
Confirmed this empirically before writing any server code: added
`spec.add_dependency "webrick", "~> 1.9"`, ran `bundle install`, then
booted a real `WEBrick::HTTPServer` with `SSLEnable: true` against the
project's own generated server cert and made a request through it with
`Net::HTTP` — before assuming the dependency would work.

- [x] Added `webrick` to the gemspec, confirmed it loads and serves
      HTTPS under `bundle exec`.

---

## Task 1: Evidence spike — log what iTAK actually sends

**Files:** `lib/ruby_tak/enrollment_server.rb` (initial catch-all)

Built `RubyTAK::EnrollmentServer` with only a catch-all handler
logging method/path/query/headers/body at INFO, returning 404 for
everything. Ran it standalone against the real, already-generated
certs and pointed iTAK at it, capturing the real request sequence
instead of guessing.

- [x] First capture: `GET /Marti/api/tls/config` (empty query, `Accept:
      */*`), server returned 404 as expected (not yet implemented) —
      confirmed the connection reaches RubyTAK at all, and the
      basic-auth header decodes to the expected `piotr:password`.
- [x] After implementing `/tls/config`, second capture showed `POST
      /Marti/api/tls/signClient/v2?clientUid=<device-uuid>&version=
      2.12.3` with a PEM-armored CSR body and `Content-Type: plain/
      text`. `version` is iTAK's own app version string, not a small
      integer — confirms it's not meaningful to react to.
- [x] Kept the catch-all (now `handle_unknown`) in the shipped code as
      permanent instrumentation for the next surprise.

---

## Task 2: Configuration and shared credentials

**Files:**
- Modify: `lib/ruby_tak/configuration.rb`
- New: `lib/ruby_tak/users.rb`
- Modify: `lib/ruby_tak/server.rb` (`handle_auth`)
- Test: `test/configuration_test.rb`

- [x] `Configuration#cert_enrollment_port` / `#cert_enrollment_port=`,
      mirroring the existing `cot_ssl_port` pattern exactly (same
      1..65535 validation, same `ArgumentError`), default 8446,
      `ENROLLMENT_PORT` env override. Test-driven: wrote the three
      `test_cert_enrollment_port_*` tests first, watched them fail
      with `NoMethodError`, then implemented.
- [x] `Server::USERS` relocated to `RubyTAK::Users.authenticate?`
      (`module_function`, matching `MessageParser`'s style). Renamed
      from `authenticate` to `authenticate?` per rubocop's
      `Naming/PredicateMethod`. `Server#handle_auth` updated to call
      it; no test referenced the old constant directly, so this was a
      safe move.

---

## Task 3: `RubyTAK::CertificateAuthority`

**Files:**
- New: `lib/ruby_tak/certificate_authority.rb`
- Test: `test/certificate_authority_test.rb`

Extracted only what CSR signing needs — deliberately did not refactor
`CLI#generate_ca_certificate`/`#generate_server_certificate` into it.

- [x] `#sign_client_csr(csr_pem, validity_days:)`: accepts PEM or bare
      base64 DER (adds PEM armor if missing), verifies the CSR's own
      signature before trusting its contents (raises
      `CertificateAuthority::InvalidCSR` otherwise), issues a cert with
      `basicConstraints=CA:FALSE`,
      `keyUsage=digitalSignature,keyEncipherment`,
      `extendedKeyUsage=clientAuth`, random 64-bit serial (same
      pattern as `cli.rb`), SHA256, 365-day validity.
- [x] Tests: signs a real CSR, asserts the result verifies against the
      CA's public key and carries `clientAuth`; a tampered CSR
      (signature no longer matches after mutating the subject) raises
      `InvalidCSR`.

---

## Task 4: `RubyTAK::EnrollmentServer` — the real endpoints

**Files:**
- Modify: `lib/ruby_tak/enrollment_server.rb`
- Test: `test/enrollment_server_test.rb`

Built incrementally against live iTAK captures rather than the initial
best-guess from reference-implementation research — three rounds of
"implement based on best evidence so far, run against real iTAK, read
what changed" before it actually worked end to end:

- [x] `GET /Marti/api/tls/config` — XML, `validityDays` from
      `CertificateAuthority::VALIDITY_DAYS`, `O=RubyTAK`/`OU=RubyTAK`
      name entries. Worked on the first attempt.
- [x] `GET /Marti/api/tls/profile/enrollment` — `204`.
- [x] `POST /Marti/api/tls/signClient/v2` — first version returned
      `{"signedCert", "ca0"}` as JSON with PEM text (armor stripped,
      internal line breaks kept), `Content-Type: application/json`
      always. **This did not work** — iTAK re-ran the whole enrollment
      every ~15s with a fresh CSR, showing the same generic auth error
      throughout, despite the HTTP exchange succeeding every time
      (verified independently with `curl` + manual `openssl` parsing).
  - Hypothesis 1 (wrong, kept anyway): embedded newlines in the base64
    broke a strict `Data(base64Encoded:)`-style decoder. Switched to
    single-line `Base64.strict_encode64(cert.to_der)`. No change in
    behavior against live iTAK — ruled out as the cause, but kept as
    the simpler encoding since it's not worse.
  - Found (independent of the main issue, but a real bug): the
    enrollment thread's startup failure was silently swallowed
    (`report_on_exception = false` with no rescue), which had actually
    been masking one entire test round. Fixed by wrapping
    `EnrollmentServer#start` in a rescue that logs the failure.
  - Hypothesis 2 (unverified, kept as defensive parity): found the
    OpenTAKServer source for this exact endpoint, including a comment
    that iTAK expects a JSON body with `Content-Type: text/plain`.
    Implemented `Content-Type` following the request's `Accept` header
    (`text/plain` → `text/plain`; `application/json`/`*/*`/missing →
    `application/json`; else → XML) at the same time as Hypothesis 3
    below. **The request that finally succeeded had `Accept: */*`** —
    identical to every prior failed attempt — so this branch was never
    actually exercised by real iTAK. Kept for parity with a known-good
    server implementation, not because it was shown to matter here.
  - Hypothesis 3 (confirmed root cause): the same OpenTAKServer source
    always includes both `ca0` and `ca1` in the response, even for a
    single CA. RubyTAK's response only had `ca0`. Added a duplicate
    `ca1`. **This was the one variable that changed between the last
    failure and the first success** — live retest showed iTAK complete
    enrollment and open a real CoT connection on 8089 immediately
    after, which stayed live streaming with no errors on either side.
- [x] Unknown paths — logged, `404`.
- [x] All authenticated routes behind HTTP Basic auth
      (`RubyTAK::Users.authenticate?`), 401 on failure.
- [x] Tests: real ephemeral-port HTTPS server per test (mirrors
      `server_test.rb`'s `with_tls_server`), covering every branch
      above including all three `Accept`-header paths and the
      invalid-CSR 400.

---

## Task 5: Lifecycle wiring

**Files:** `lib/ruby_tak/server.rb`, `test/server_test.rb`

- [x] `Server#initialize` takes an injectable `enrollment_server:`
      (defaults to `EnrollmentServer.new(logger:)`), constructed
      without binding anything (matches the existing test convention
      of constructing `Server` without a real bind).
- [x] `Server#start` launches it via a new private
      `start_enrollment_server`, in its own thread, wrapped in a
      rescue that logs `StandardError` — found necessary the hard way
      (see Task 4).
- [x] `Server#shutdown` calls `@enrollment_server.shutdown` before
      closing the CoT socket, since `#start`'s `rescue Interrupt` only
      covers the main accept loop's thread.
- [x] `test/server_test.rb`'s `with_tls_server` helper updated to also
      stub `cert_enrollment_port` to an ephemeral port and shut down
      the enrollment server in its `ensure` block, so existing
      real-socket TLS tests don't try to bind the real 8446.
- [x] New test: a mock `enrollment_server` that raises on `#start`
      asserts the failure is logged.

---

## Task 6: Documentation

**Files:** `README.md`, `CHANGELOG.md`, this pair of docs

- [x] Design spec + this plan, under `docs/superpowers/`, matching the
      TLS-support pair's format and explicitly reversing that spec's
      "no enrollment API" non-goal with the reason why.
- [x] README: document adding RubyTAK in iTAK as a "TAK Server" entry
      (host, port 8446, username, password).
- [x] CHANGELOG: `[Unreleased]` entry.

---

## Task 7: Full verification

**Files:** None (verification only).

- [x] `./bin/rake` (tests + rubocop) — 100 runs, 0 failures, no
      rubocop offenses.
- [x] `CI=1 ./bin/rake test` — 100% line coverage.
- [x] End-to-end with the real iTAK app: added RubyTAK as a "TAK
      Server" entry, confirmed enrollment completes and a live CoT
      connection opens and stays established, with the client showing
      "connected" and no error.
