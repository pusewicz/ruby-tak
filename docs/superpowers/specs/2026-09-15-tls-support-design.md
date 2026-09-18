# TLS support for the CoT streaming server

## Problem

`RubyTAK::Server` listens on the port it calls `cot_ssl_port` (default
8089), but never actually speaks TLS — it's a plain `TCPServer`. TAK
clients (iTAK confirmed via packet capture) refuse to stream CoT data
over that port without a trusted TLS certificate: any "Add Server"
attempt first probes a certificate-trust/enrollment style connection
and aborts if that fails, regardless of the chosen protocol or
whether credentials are supplied.

Investigation (see conversation history) ruled out two lighter
alternatives:
- A legacy `.pref`-based data package (matching this project's
  pre-2023 `client` command) is silently ignored by current iTAK —
  that storage format is obsolete.
- A bare TLS handshake against the existing self-signed cert is
  actively rejected by iTAK before it sends any request, because the
  cert isn't trusted and doesn't cover the connecting IP.

Confirmed with the project owner: iTAK only needs a certificate it
trusts — no dynamic certificate-signing/enrollment API, no mutual TLS.

## Goals

- `cot_ssl_port` actually terminates TLS, using the cert/key already
  produced by `ruby_tak certificate server`.
- The generated server certificate is valid for however the client
  actually reaches the box (hostname, loopback, and every local IPv4
  address), not just hostname + `127.0.0.1`.
- A slow or malformed TLS handshake from one connection cannot block
  other clients from connecting.
- Existing username/password auth (the `<auth>` CoT message) keeps
  working unchanged.
- Document how to get a client to trust the CA (macOS Keychain for
  local testing, iOS configuration profile for real devices).

## Non-goals

- Mutual TLS / per-client certificates. iTAK doesn't require the
  server to authenticate clients this way, and this project already
  has an application-level username/password auth mechanism.
- A certificate-enrollment HTTP(S) API (the "Marti API" port 8446
  real TAK Servers expose). Not needed once the client already trusts
  the CA out of band.
- Reviving the old `.pref` data-package / `client` CLI command. Its
  format is confirmed obsolete in current iTAK; superseded by the
  standard iOS "install profile" trust flow, which isn't
  iTAK-version-dependent.
- Any change to the Traefik/Docker production deployment path — that
  code no longer exists in this repo and is out of scope here.

## Architecture

### TLS handshake location

The listening socket stays a plain `TCPServer`, unchanged. TLS wrapping
and the handshake happen inside `handle_accept`, per connection,
inside the thread that's already spawned there — not in the main
accept loop. Concretely: after `@server.accept` returns a raw
`TCPSocket`, wrap it in an `OpenSSL::SSL::SSLSocket` bound to the
server's `SSLContext` and call `#accept` on *that* to perform the
handshake, before constructing the `Client`.

This keeps the accept loop itself fast and untouched by handshake
cost or failures — a stalled or hostile handshake only ties up its own
thread, matching how a bad client already can't block others today.

`SSLContext` is built once at `Server#initialize` time from
`config.server_crt_path` / `config.server_key_path`. `verify_mode` is
`OpenSSL::SSL::VERIFY_NONE` — no client certificate is requested,
matching the "no mutual TLS" decision above.

### Certificate SAN fix

`ruby_tak certificate server` (in `cli.rb`) currently hardcodes
`subjectAltName` to `DNS:#{hostname},IP:127.0.0.1`. It needs to also
include every local, non-loopback IPv4 address found on the machine
(via `Socket.ip_address_list`), so a client connecting over LAN sees a
cert that actually covers the IP it dialed. No new CLI flags — this
is fully automatic.

### Error handling

Handshake failures raise `OpenSSL::SSL::SSLError`; this is caught
inside the same per-thread rescue chain `handle_accept` already has,
logged, and that connection is closed — it must not affect other
connected clients or the accept loop. Follows this repo's existing
convention of catching specific exception classes rather than blanket
`StandardError` for expected-ish conditions, and reusing the "log and
disconnect" pattern already used for `IOError`/`Errno::ECONNRESET`.

### What doesn't change

- `Client`'s framing/parsing code (`extract_messages`, etc.) — an
  `SSLSocket` supports the same `readpartial`/`write`/`close` surface
  the code already uses.
- The `<auth>` CoT message flow in `Server#handle_auth`.
- `MAX_CONNECTIONS`, the connection watchdog, broadcast logic.

## Testing

- Existing accept-loop tests (which mock `TCPServer.new` and stub
  `handle_accept`) are unaffected — the loop itself still just calls
  `accept`.
- New tests exercise the TLS path with real sockets: generate a
  throwaway self-signed cert/key in `Dir.mktmpdir` (matching this
  repo's established temp-dir pattern), start a real `Server` on an
  ephemeral port, and connect with a real `OpenSSL::SSL::SSLSocket`
  client to confirm a handshake + `<auth>` message round-trip
  succeeds.
- A second test connects with a plain (non-TLS) `TCPSocket` (or a
  socket that sends garbage) to confirm the handshake fails cleanly:
  the server logs and drops that connection without crashing or
  affecting other clients.
- `ruby_tak certificate server`'s SAN generation gets a unit test
  confirming detected local IPs end up in the cert.
- CI requires 100% line coverage (`test/test_helper.rb`) — all new
  branches (success path, handshake-failure path) need explicit
  coverage.

## Documentation

Add a short section to `README.md`: how to trust the CA cert —
import into macOS Keychain (local Mac testing, e.g. "Designed for
iPad" apps) and install as an iOS configuration profile (real
devices). Both are standard OS-level features, not iTAK-specific
behavior, so they don't depend on reverse-engineering app internals.
