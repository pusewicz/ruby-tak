# Development Guide for Claude Code

This document captures conventions and best practices for this codebase.

## Running Tests and Linting

**Always run the full test suite before considering work complete:**

```bash
./bin/rake  # Runs both tests AND rubocop
```

Not just `./bin/rake test` - we need both tests and linting to pass.

## Code Style

### Arrays of Strings

Use `%w[]` for word arrays:

```ruby
# Good
@cli.run(%w[certificate ca])

# Bad
@cli.run(["certificate", "ca"])
```

### Numeric Literals

Use proper prefixes for non-decimal numbers:

```ruby
# Good
File.chmod(0o600, file_path)

# Bad
File.chmod(0600, file_path)
```

### Assertions in Tests

Use predicate assertions when available:

```ruby
# Good
assert_predicate file_path, :exist?

# Bad
assert file_path.exist?
```

Limit assertions per test to 3 or fewer. Split into multiple tests if needed.

## Exception Handling

### Exception Hierarchies

Be aware of Ruby exception hierarchies to avoid shadowing:

```ruby
# Good - IOError includes EOFError
rescue IOError, Errno::ECONNRESET

# Bad - EOFError is redundant (subclass of IOError)
rescue EOFError, IOError, Errno::ECONNRESET
```

### Normal vs Error Conditions

Don't count normal operation as errors:

```ruby
# Client disconnects are normal, not errors
rescue IOError, Errno::EBADF
  # Normal disconnect
  @running = false
rescue StandardError => e
  # Actual error
  @stats[:errors] += 1
end
```

## Thread Safety

### Mutex for Shared State

Always use mutex when accessing shared collections from multiple threads:

```ruby
# Good - single synchronized block
result, count = @clients_mutex.synchronize do
  [@clients.delete(client), @clients.size]
end

# Bad - multiple synchronized blocks
@clients_mutex.synchronize { @clients.delete(client) }
count = @clients_mutex.synchronize { @clients.size }
```

### Broadcast Pattern

Copy collection before iterating to avoid modification during iteration:

```ruby
clients_to_broadcast = @clients_mutex.synchronize { @clients.to_a }
clients_to_broadcast.each do |client|
  # Safe to modify @clients here
end
```

## CLI Patterns

### Subcommands with OptionParser

```ruby
subcommands = {
  "command" => OptionParser.new do |opts|
    opts.banner = "Usage: ruby_tak command [options]"
    opts.on("-f", "--flag VALUE", "Description") { |v| options[:flag] = v }
  end
}

global.order!(args)  # Parse global options
command = args.shift
subcommands[command]&.order!(args)  # Parse subcommand options
```

Always pass `args` to `order!` - it defaults to `ARGV` which breaks tests.

### Testing CLI Commands

Capture output to avoid test noise:

```ruby
output = capture_io do
  @cli.run(%w[command arg])
end

assert_match(/expected text/, output[0])
```

## TAK Server Compatibility

### Certificate Standards

#### CA Certificate

- **Key size**: 2048-bit RSA (TAK standard)
- **Validity**: 3652 days (10 years)
- **Signature**: SHA256
- **Extensions**: basicConstraints=CA:TRUE, keyUsage=keyCertSign,cRLSign
- **Subject**: CN=RubyTAK CA, O=RubyTAK, C=US

#### Server Certificate

- **Key size**: 2048-bit RSA (TAK standard)
- **Validity**: 730 days (2 years)
- **Signature**: SHA256
- **Signed by**: CA certificate
- **Extensions**:
  - basicConstraints=CA:FALSE
  - keyUsage=digitalSignature,keyEncipherment
  - extendedKeyUsage=serverAuth,clientAuth
  - subjectAltName=DNS:hostname,IP:127.0.0.1
- **Subject**: CN=hostname, O=RubyTAK, C=US
- **Serial**: Random 64-bit number

## File Structure

```
lib/ruby_tak/
  cli.rb           # Command-line interface
  server.rb        # Main server logic
  client.rb        # Client connection wrapper
  message.rb       # Message parsing/handling
  configuration.rb # App configuration

test/
  *_test.rb       # Minitest tests

benchmarks/       # Performance testing scripts
```

## Configuration

Uses XDG directories via the `xdg` gem:

- Certificates: `~/.config/ruby_tak/certs/`
- Data packages: `~/.local/share/ruby_tak/data_packages/`

Validate configuration values in setters:

```ruby
def port=(value)
  port = Integer(value)
  raise ArgumentError, "port must be..." unless (1..65_535).cover?(port)
  @port = port
end
```

## Refactoring Principles

### DRY - Don't Repeat Yourself

Extract common patterns:

```ruby
# Before
def build_point
  Ox::Element.new("point").tap { |e| @point.each { |k, v| e[k] = v } }
end

def build_detail
  Ox::Element.new("detail").tap { |e| @detail.each { |k, v| e[k] = v } }
end

# After
def build_element(name, attributes)
  Ox::Element.new(name).tap { |e| attributes.each { |k, v| e[k] = v } }
end
```

### Efficient Resource Usage

Minimize mutex contention, inline unnecessary variables, handle errors gracefully.

## Testing Best Practices

### Temporary Directories

Always use temporary directories for file tests:

```ruby
Dir.mktmpdir do |tmpdir|
  config.stub :certs_dir, Pathname.new(tmpdir) do
    # Test code that creates files
  end
end
```

### Stub External Dependencies

Don't actually start servers or make network calls in tests:

```ruby
RubyTAK::Server.stub :start, nil do
  @cli.run(%w[server])
end
```

## Common Gotchas

1. **OpenSSL::PKCS12.create** uses SHA256 MAC by default (breaks ATAK) - use system `openssl` command
2. **OptionParser#order!** without args uses `ARGV` not your array - always pass `args`
3. **Set iteration** during modification causes RuntimeError - copy before iterating
4. **EOFError** is a subclass of IOError - don't rescue both
5. **File.chmod** permissions need octal prefix `0o`

## Debugging

Enable debug logging:

```bash
DEBUG=1 ./exe/ruby_tak server
```

Run specific test:

```bash
ruby -Itest test/cli_test.rb -n test_certificate_ca_generates_files
```

## Performance

For 100+ concurrent connections:
- Use thread-safe collections
- Minimize lock contention
- Handle write failures gracefully
- Implement connection/write timeouts
- Add max connection limits

See `benchmarks/` directory for profiling tools.

## Documentation Style

- Keep explanations concise
- Add comments for non-obvious decisions (e.g., "SHA1 MAC for ATAK compatibility")
- Document WHY not WHAT when it matters
- Update README.md for user-facing changes
- Don't create docs unless explicitly requested
