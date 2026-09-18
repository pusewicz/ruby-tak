# TLS Support for the CoT Streaming Server — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `cot_ssl_port` actually speak TLS (it's currently plain TCP), using a self-signed certificate that covers every IP the server can be reached on, so TAK clients (confirmed with iTAK) will trust it and stream.

**Architecture:** The listening `TCPServer` stays plain and unchanged. Each accepted raw socket is wrapped in an `OpenSSL::SSL::SSLSocket` and handshaken inside its own thread (a new `accept_connection` method), so one slow/bad handshake can't block other clients. Once the handshake succeeds, the existing `handle_accept` method takes over completely unchanged — it doesn't know or care that its socket is TLS-wrapped. No client certificates, no certificate-signing API.

**Tech Stack:** Ruby stdlib `openssl` (already a transitive dependency via Ruby itself, no new gem), existing `Minitest`/`SimpleCov` test setup.

**Spec:** `docs/superpowers/specs/2026-09-15-tls-support-design.md`

## Global Constraints

- CI requires 100% line coverage (`test/test_helper.rb`, `minimum_coverage 100 if ENV["CI"]`) — every new branch needs a test that exercises it.
- Run `./bin/rake` (tests + rubocop) before considering any task done — not just `./bin/rake test`.
- No mutual TLS / client certificates — `verify_mode` is `OpenSSL::SSL::VERIFY_NONE`.
- No certificate-enrollment HTTP API (no port 8446 work) — out of scope per spec.
- Follow this repo's exception-hierarchy convention: catch specific exception classes before any blanket `StandardError`, and don't list a subclass alongside a class that already covers it (e.g. never `rescue EOFError, IOError`).
- Minitest: keep to 3 or fewer assertions per test (CLAUDE.md; rubocop's hard cap here is 5) — split into multiple tests if you need more.
- `%w[]` for string arrays, `0o` prefix for octal literals, `assert_predicate` over `assert x.exist?`, per CLAUDE.md code style.

---

## Task 1: Fix the server certificate's SAN to cover every local IP

**Files:**
- Modify: `lib/ruby_tak/cli.rb` (`generate_server_certificate`, ~line 133-202)
- Test: `test/cli_test.rb`

**Interfaces:**
- Produces: a private `CLI#subject_alt_name(config)` method returning a String like `"DNS:host,IP:127.0.0.1,IP:192.168.1.5"`. Not consumed elsewhere — used only within `generate_server_certificate`.

The current SAN is hardcoded to `"DNS:#{config.hostname},IP:127.0.0.1"`, which is why iTAK rejected the cert when connecting over the LAN IP — that IP was never listed as valid. This task makes the SAN include every non-loopback IPv4 address the machine actually has, automatically (no new CLI flags).

- [ ] **Step 1: Write the failing test**

Add to `test/cli_test.rb`, near the other `test_certificate_server_*` tests:

```ruby
  def test_certificate_server_includes_local_ips_in_san
    Dir.mktmpdir do |tmpdir|
      config = RubyTAK.configuration
      config.stub :certs_dir, Pathname.new(tmpdir) do
        capture_io { @cli.run(%w[certificate ca]) }

        fake_ip = Addrinfo.ip("203.0.113.10")
        Socket.stub :ip_address_list, [fake_ip] do
          capture_io { @cli.run(%w[certificate server]) }
        end

        server_crt_path = Pathname.new(tmpdir).join(config.server_crt)
        cert = OpenSSL::X509::Certificate.new(File.read(server_crt_path))
        san_extension = cert.extensions.find { |ext| ext.oid == "subjectAltName" }

        assert_includes san_extension.value, "203.0.113.10"
      end
    end
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ruby -Itest test/cli_test.rb -n test_certificate_server_includes_local_ips_in_san`
Expected: FAIL — the assertion fails because the current SAN never includes `203.0.113.10` (it's hardcoded to hostname + `127.0.0.1` only).

- [ ] **Step 3: Implement the SAN fix**

In `lib/ruby_tak/cli.rb`, inside `generate_server_certificate` (private method, starts ~line 133), add `require "socket"` at the top alongside the existing `require "openssl"`:

```ruby
    def generate_server_certificate
      require "openssl"
      require "socket"
```

Replace this line (~line 187-189):

```ruby
      server_cert.add_extension(
        ef.create_extension("subjectAltName", "DNS:#{config.hostname},IP:127.0.0.1", false)
      )
```

with:

```ruby
      server_cert.add_extension(
        ef.create_extension("subjectAltName", subject_alt_name(config), false)
      )
```

Add a new private method right after `generate_server_certificate` (before the closing `end` of the class):

```ruby
    def subject_alt_name(config)
      local_ips = Socket.ip_address_list.select(&:ipv4?).map(&:ip_address).uniq
      entries = ["DNS:#{config.hostname}"] + local_ips.map { |ip| "IP:#{ip}" }
      entries.join(",")
    end
```

`Socket.ip_address_list` already includes `127.0.0.1` (it's a normal IPv4 loopback interface address), so the old hardcoded `IP:127.0.0.1` entry doesn't need to be kept separately — it's covered automatically.

- [ ] **Step 4: Run test to verify it passes**

Run: `ruby -Itest test/cli_test.rb -n test_certificate_server_includes_local_ips_in_san`
Expected: PASS

- [ ] **Step 5: Run the full CLI test file to make sure nothing else broke**

Run: `ruby -Itest test/cli_test.rb`
Expected: all tests PASS (in particular `test_certificate_server_generates_valid_x509` and `test_certificate_server_signed_by_ca`, which don't stub `Socket.ip_address_list` and will pick up this machine's real IPs — they don't assert anything about SAN content, so they're unaffected).

- [ ] **Step 6: Commit**

```bash
git add lib/ruby_tak/cli.rb test/cli_test.rb
git commit -m "Include all local IPv4 addresses in server cert SAN"
```

---

## Task 2: Add real TLS to the server's accept path

**Files:**
- Modify: `lib/ruby_tak/server.rb`
- Test: `test/server_test.rb`

**Interfaces:**
- Consumes: `RubyTAK.configuration.server_crt_path` / `server_key_path` (existing, from `lib/ruby_tak/configuration.rb`).
- Produces: private `Server#ssl_context` (memoized `OpenSSL::SSL::SSLContext`) and private `Server#accept_connection(socket)`. `start`'s loop now calls `accept_connection` instead of `handle_accept` directly; `handle_accept`'s own signature and behavior are **unchanged** — it still just takes "a socket ready for `readpartial`/`write`/`close`/`peeraddr`", which is true of both a raw `TCPSocket` (existing tests) and a post-handshake `SSLSocket` (production).

The SSL context is built **lazily** (memoized on first use, not in `initialize`) specifically so that none of the existing tests — which construct a `Server` via a stubbed `TCPServer.new` and never call `accept_connection` — need real certificate files on disk. Only the new TLS-handshake tests below (which generate real certs in a tmpdir first) ever trigger it.

- [ ] **Step 1: Update the accept-loop test to match the new dispatch method**

`test_start_runs_accept_loop` currently stubs `handle_accept`. Once the loop calls a new `accept_connection` method instead, update the stub target. Edit `test/server_test.rb` (~line 37-51):

```ruby
  def test_start_runs_accept_loop
    server = create_server
    @mock_tcp_server.expect(:accept, :fake_socket)
    @mock_tcp_server.expect(:accept, nil) { raise StopIteration }

    accepted = []
    server.stub(:accept_connection, ->(socket) { accepted << socket }) do
      server.stub(:start_connection_watchdog, nil) do
        server.start
      end
    end

    assert_equal [:fake_socket], accepted
    @mock_tcp_server.verify
  end
```

(Only the stubbed method name changed, from `:handle_accept` to `:accept_connection`.)

- [ ] **Step 2: Run it to verify it fails (method doesn't exist yet)**

Run: `ruby -Itest test/server_test.rb -n test_start_runs_accept_loop`
Expected: FAIL — `start` still calls `handle_accept` directly, so `accepted` stays empty (the stub on `accept_connection` is never hit).

- [ ] **Step 3: Add the TLS handshake wrapping to server.rb**

In `lib/ruby_tak/server.rb`, add `require "openssl"` to the top requires (~line 3-4):

```ruby
require "openssl"
require "ox"
require "socket"
```

Change `start` (~line 32-38) to dispatch through the new method:

```ruby
    def start
      start_connection_watchdog
      loop do
        socket = @server.accept
        accept_connection(socket)
      end
    end
```

Add `accept_connection` and `ssl_context` as new private methods. Insert them right before `handle_accept` (~line 63), so the accept-path methods read top to bottom in call order:

```ruby
    def accept_connection(socket)
      client_count = @clients_mutex.synchronize { @clients.size }
      if client_count >= MAX_CONNECTIONS
        logger.warn("MAX_CONNECTIONS reached, rejecting connection")
        socket.close
        return
      end

      Thread.start(socket) do |raw_socket|
        ssl_socket = OpenSSL::SSL::SSLSocket.new(raw_socket, ssl_context)
        ssl_socket.sync_close = true

        begin
          ssl_socket.accept
        rescue OpenSSL::SSL::SSLError => e
          logger.debug("TLS handshake failed: #{e.class} #{e.message}")
          raw_socket.close
          Thread.exit
        rescue IOError, Errno::ECONNRESET => e
          logger.debug("Connection closed during TLS handshake: #{e.class}")
          raw_socket.close
          Thread.exit
        end

        handle_accept(ssl_socket)
      end
    end

    def ssl_context
      @ssl_context ||= begin
        config = RubyTAK.configuration
        context = OpenSSL::SSL::SSLContext.new
        context.cert = OpenSSL::X509::Certificate.new(File.read(config.server_crt_path))
        context.key = OpenSSL::PKey::RSA.new(File.read(config.server_key_path))
        context.verify_mode = OpenSSL::SSL::VERIFY_NONE
        context
      end
    end
```

Note this duplicates the `MAX_CONNECTIONS` check that already exists at the top of `handle_accept` — that's intentional: it lets over-capacity connections get rejected instantly, before paying for a TLS handshake, exactly like today. `handle_accept`'s own check stays as a second, authoritative guard against a race between the two.

- [ ] **Step 4: Run the accept-loop test again to verify it passes**

Run: `ruby -Itest test/server_test.rb -n test_start_runs_accept_loop`
Expected: PASS

- [ ] **Step 5: Run the full server test file to confirm nothing else broke**

Run: `ruby -Itest test/server_test.rb`
Expected: all existing tests PASS unchanged — none of them call `accept_connection` or `ssl_context`, so they never touch real certificate files.

- [ ] **Step 6: Write the failing integration test for a successful TLS handshake**

Add to `test/server_test.rb`, at the end of the `ServerTest` class (before the final `end`):

```ruby
  def test_accept_connection_completes_tls_handshake_and_processes_auth
    Dir.mktmpdir do |tmpdir|
      config = RubyTAK.configuration
      config.stub :certs_dir, Pathname.new(tmpdir) do
        capture_io { RubyTAK::CLI.new.run(%w[certificate ca]) }
        capture_io { RubyTAK::CLI.new.run(%w[certificate server]) }

        config.stub :cot_ssl_port, 0 do
          server = RubyTAK::Server.new(logger: @logger)
          port = server.instance_variable_get(:@server).addr[1]
          server_thread = Thread.new { server.start }
          sleep 0.1

          begin
            tcp_socket = TCPSocket.new("127.0.0.1", port)
            client_ssl_context = OpenSSL::SSL::SSLContext.new
            client_ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
            ssl_socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, client_ssl_context)
            ssl_socket.connect

            ssl_socket.write('<auth><cot username="piotr" password="password" uid="TLS-TEST-UID"/></auth>')
            sleep 0.2

            clients = server.instance_variable_get(:@clients_mutex).synchronize do
              server.instance_variable_get(:@clients).to_a
            end

            assert_equal 1, clients.size
            assert_equal "TLS-TEST-UID", clients[0].uid
          ensure
            ssl_socket&.close
            server_thread.kill
          end
        end
      end
    end
  end
```

Requires `Pathname` and `TCPSocket`/`OpenSSL` to be available in the test file — `test/server_test.rb` already `require "socket"`; add `require "pathname"` and `require "openssl"` to its top requires (~line 3-5):

```ruby
require "test_helper"
require "openssl"
require "pathname"
require "stringio"
require "socket"
```

- [ ] **Step 7: Run it to verify it fails**

Run: `ruby -Itest test/server_test.rb -n test_accept_connection_completes_tls_handshake_and_processes_auth`
Expected: FAIL at this point only if Step 3 wasn't done — since Step 3 already landed, this should actually PASS already. If it fails, re-check that `ssl_context` reads `config.server_crt_path`/`server_key_path` correctly (both should resolve under the stubbed `certs_dir`).

- [ ] **Step 8: Confirm it passes on its own**

Run: `ruby -Itest test/server_test.rb -n test_accept_connection_completes_tls_handshake_and_processes_auth`
Expected: PASS

- [ ] **Step 9: Write the failing integration test for a rejected (non-TLS) handshake**

Add directly after the previous test:

```ruby
  def test_accept_connection_handles_non_tls_client_without_crashing
    Dir.mktmpdir do |tmpdir|
      config = RubyTAK.configuration
      config.stub :certs_dir, Pathname.new(tmpdir) do
        capture_io { RubyTAK::CLI.new.run(%w[certificate ca]) }
        capture_io { RubyTAK::CLI.new.run(%w[certificate server]) }

        config.stub :cot_ssl_port, 0 do
          server = RubyTAK::Server.new(logger: @logger)
          port = server.instance_variable_get(:@server).addr[1]
          server_thread = Thread.new { server.start }
          sleep 0.1

          begin
            tcp_socket = TCPSocket.new("127.0.0.1", port)
            tcp_socket.write("not a tls client hello\n")
            sleep 0.2

            clients = server.instance_variable_get(:@clients_mutex).synchronize do
              server.instance_variable_get(:@clients).to_a
            end

            assert_empty clients
          ensure
            tcp_socket&.close
            server_thread.kill
          end
        end
      end
    end
  end
```

- [ ] **Step 10: Run it to verify it passes**

Run: `ruby -Itest test/server_test.rb -n test_accept_connection_handles_non_tls_client_without_crashing`
Expected: PASS — the server logs a debug line and closes that connection; `@clients` stays empty.

- [ ] **Step 11: Run the full server test file**

Run: `ruby -Itest test/server_test.rb`
Expected: all tests PASS.

- [ ] **Step 12: Commit**

```bash
git add lib/ruby_tak/server.rb test/server_test.rb
git commit -m "Terminate real TLS on the CoT streaming port"
```

---

## Task 3: Document how to trust the CA certificate

**Files:**
- Modify: `README.md`

**Interfaces:** None — documentation only.

- [ ] **Step 1: Add a "Trusting the certificate" section to README.md**

Add this new section after the existing "Quick start" section (after the `client.zip`/iTAK line, before "## Development"):

```markdown
## Trusting the certificate

RubyTAK signs its own certificates — there's no public CA — so each client
needs to be told to trust `ruby_tak-ca.crt` (from
`~/.config/ruby_tak/certs/`) before it will connect:

- **macOS** (including a "Designed for iPad/iPhone" TAK app running
  natively on Apple Silicon): open the `.crt` file in Keychain Access to
  import it, then double-click the imported certificate and set "When
  using this certificate" to **Always Trust**.
- **iOS/iPadOS**: AirDrop or email `ruby_tak-ca.crt` to the device, open
  it to install it as a configuration profile (Settings → General → VPN
  & Device Management), then enable full trust for it under Settings →
  General → About → Certificate Trust Settings.
```

- [ ] **Step 2: Proofread the rendered markdown**

Run: `cat README.md` and read the new section in context — confirm it sits between "Quick start" and "Development" and the heading levels match the rest of the file (`##` for top-level sections, matching `## Quick start` / `## Development`).

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "Document how to trust the RubyTAK CA certificate"
```

---

## Task 4: Full verification

**Files:** None (verification only).

- [ ] **Step 1: Run the full test and lint suite**

Run: `./bin/rake`
Expected: all tests pass, rubocop reports no offenses.

- [ ] **Step 2: Check coverage**

Run: `CI=1 ./bin/rake test`
Expected: passes with 100% line coverage (SimpleCov enforces this when `CI` is set — this is exactly what the CI pipeline runs).

- [ ] **Step 3: If anything fails, fix and re-run**

Fix any failure or coverage gap directly in the relevant file from Task 1-3, re-run `./bin/rake`, and commit the fix:

```bash
git add -A
git commit -m "Fix issues found during full verification"
```

Only do this if Step 1 or Step 2 actually failed — skip if both passed cleanly.
