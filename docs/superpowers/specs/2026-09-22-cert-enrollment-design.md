# Certificate enrollment API for TAK clients

## Problem

The previous TLS-support work (see `2026-09-15-tls-support-design.md`)
assumed that once a client trusted RubyTAK's CA, it would connect
straight to the CoT streaming port. Live testing against iTAK, after
trusting the CA, still failed with "There was an error authenticating
with the server, please try again" — and nothing appeared in
RubyTAK's server logs at all.

Unified-log capture of the real iTAK process
(`log stream --predicate 'process == "iTAK App Store"'`) showed why:
when a server is added in iTAK as a **"TAK Server"** entry with a
username and password (rather than a plain streaming connection),
iTAK first calls a certificate-enrollment REST API on port 8446
(`GET /Marti/api/tls/config`, `POST /Marti/api/tls/signClient/v2`) to
trade the username/password for a short-lived client certificate —
entirely before it ever opens the CoT socket. RubyTAK had no HTTP
surface at all, so this connection got refused outright, which is why
the CoT port's log stayed silent through the whole investigation.

This reverses that prior spec's explicit non-goal of not building this
API. That decision assumed CA trust alone was sufficient; it wasn't,
for this connection type.

## Goals

- Adding RubyTAK in iTAK as a "TAK Server" entry (host, port 8446,
  username, password) completes enrollment and the client then streams
  CoT on the existing port automatically — the standard onboarding
  path.
- The enrollment API is signed by the same CA RubyTAK already
  generates (`ruby_tak certificate ca`) — no new certificate
  infrastructure or trust store.
- Username/password auth stays the single source of truth
  (`RubyTAK::Users`, shared with the CoT `<auth>` flow) — enrollment
  doesn't add a second credential store.
- Any unrecognized request to the enrollment port is logged (method,
  path, query, headers, body) rather than silently dropped — this
  endpoint's contract was reverse-engineered against a closed-source
  client and will likely need this instrumentation again.

## Non-goals

- Mutual TLS on the CoT port (8089). Enrollment issues a client
  certificate, but 8089's `SSLContext` still uses `VERIFY_NONE` —
  confirmed live that iTAK connects and streams fine without
  presenting it. Revisit only if a client is found that requires it.
- The `/Marti/api/tls/profile/enrollment` endpoint returning actual
  profile content, or reviving the legacy `.pref` data-package format.
  RubyTAK returns `204 No Content` there (matching real TAK Server's
  default), and iTAK proceeds without it.
- The `/Marti/api/tls/signClient` (v1, no `/v2`) endpoint. Never
  observed in a real request from iTAK; add it if a client that needs
  it turns up.
- Any change to `ruby_tak certificate ca`/`server` CLI generation —
  enrollment only *consumes* the existing CA.

## Architecture

### New HTTP(S) listener

`RubyTAK::EnrollmentServer` runs a `WEBrick::HTTPServer` bound to
`config.cert_enrollment_port` (default 8446, `ENROLLMENT_PORT` env
override), using the *same* server certificate/key as the CoT port —
matching how real TAK Server terminates both ports with one server
cert, since the client has nothing to verify the server against until
enrollment completes. `Server#start` launches it in its own thread and
`Server#shutdown` tears it down; a bind failure (e.g. the port already
in use) is caught and logged rather than silently killing the thread —
this happened once during manual testing and cost a debugging round
before the fix.

`webrick` is a new runtime dependency (`~> 1.9`). It is not a default
gem under Ruby 4.0, and `lib/ruby_tak.rb` runs `require
"bundler/setup"`, which prunes `$LOAD_PATH` to declared gems — a
globally-installed webrick is invisible to the app without this.

### Endpoints

Reverse-engineered from live capture of real iTAK requests, cross-
checked against three reference server implementations (the official
TAK Server, `kdudkov/goatak`, `brian7704/OpenTAKServer`):

- `GET /Marti/api/tls/config` — XML `<certificateConfig>` advertising
  `validityDays` and the subject `O`/`OU` iTAK should put in its CSR.
- `POST /Marti/api/tls/signClient/v2?clientUid=...&version=...` — body
  is a PEM-armored CSR (iTAK sends this despite a `Content-Type:
  plain/text` header on the request, which is ignored). Response is
  JSON `{"signedCert": ..., "ca0": ..., "ca1": ...}`, each value a
  base64 encoding of DER bytes (not PEM). **`ca1` must be present even
  with a single-level CA** — RubyTAK has no intermediate, so it
  duplicates `ca0`. This is the confirmed root cause of a silent
  client-side rejection found during testing: with only `ca0` present,
  the HTTP exchange itself succeeded every time (200, a validly-signed
  cert, verified independently with `openssl`/`curl`), but iTAK
  discarded the result and re-ran the whole enrollment from scratch on
  every manual retry, with no server-side signal anything was wrong.
  Adding `ca1` — the one change made in the request that finally
  succeeded — was immediately followed by iTAK completing enrollment
  and opening a live CoT connection.

  Two other changes were made earlier in the same debugging session
  and kept in the final code, but **neither was verified as necessary
  against real iTAK**: the request that finally succeeded had
  `Accept: */*`, identical to every failed attempt, so the
  `Content-Type`-matching logic below is defensive parity with
  OpenTAKServer (whose source carries the comment "iTAK expects a JSON
  response but with the Content-Type header set to text/plain for some
  reason") rather than a confirmed requirement — iTAK has never
  actually been observed sending `Accept: text/plain`. Likewise,
  switching from multi-line PEM-derived base64 to single-line
  `Base64.strict_encode64` was a discarded hypothesis (embedded
  newlines breaking a strict decoder) that made no observed difference
  on its own; it's kept as the simpler, safer encoding, not because it
  was shown to matter. If a future client needs different handling
  here, re-verify from scratch rather than trusting these as
  discovered constraints.

  Response `Content-Type` follows the request's `Accept` header
  (`text/plain` → `text/plain`; `application/json` / `*/*` / missing →
  `application/json`; anything else → an XML body).
- `GET /Marti/api/tls/profile/enrollment` — `204 No Content`.
- Anything else — logged at INFO (method, path, query, headers, body)
  and `404`.

All routes except the catch-all require HTTP Basic auth via
`RubyTAK::Users.authenticate?`.

### Certificate signing

`RubyTAK::CertificateAuthority` loads the CA cert/key from the
existing `config.ca_crt_path`/`ca_key_path` and signs client CSRs: it
accepts either PEM or bare base64 DER, verifies the CSR's own
signature before trusting anything in it, then issues a certificate
with `basicConstraints=CA:FALSE`,
`keyUsage=digitalSignature,keyEncipherment`,
`extendedKeyUsage=clientAuth`, a random 64-bit serial (matching the
pattern already used in `cli.rb`), signed SHA256, valid for
`VALIDITY_DAYS` (365) — the same number advertised in `/tls/config`.

### Shared credentials

`Server::USERS` moved to `RubyTAK::Users.authenticate?(username,
password)` so both the CoT `<auth>` flow and the enrollment Basic-auth
check share one source of truth.

### What doesn't change

- The CoT port's `SSLContext` (`VERIFY_NONE`) and `handle_auth`'s
  `<auth>` message flow. Confirmed live: iTAK doesn't send `<auth>`
  once it holds a client certificate, and `client.username` staying
  `nil` in that case is harmless — only `uid` (set from the connection
  itself, not from `<auth>`) is read anywhere else in `lib/`.
- Certificate generation (`ruby_tak certificate ca`/`server`).

## Testing

- `RubyTAK::CertificateAuthority`: signs a real CSR built in-test,
  asserts the result verifies against the CA's public key and carries
  `clientAuth` in `extendedKeyUsage`; a tampered CSR raises
  `InvalidCSR`.
- `RubyTAK::EnrollmentServer`: a real ephemeral-port HTTPS server per
  test (mirrors `server_test.rb`'s `with_tls_server` helper),
  exercising `/tls/config`, `/signClient/v2` (JSON, `text/plain`, and
  XML `Accept` branches, plus an invalid-CSR 400), `/profile/
  enrollment`, an unknown path (404), and bad credentials (401).
- `RubyTAK::Server`: the enrollment listener now starts alongside the
  CoT listener in `#start`/`#shutdown`; a test forces
  `EnrollmentServer#start` to raise and asserts the failure is logged
  rather than silently swallowed.
- CI requires 100% line coverage — every new branch is covered
  explicitly.

## Documentation

README gains a short section on adding RubyTAK as a "TAK Server" entry
in iTAK (host, port 8446, username, password), alongside the existing
CA-trust instructions.
