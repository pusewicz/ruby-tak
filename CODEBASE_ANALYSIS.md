# RubyTAK Codebase Analysis

## Project Overview

**Project:** RubyTAK - TAK Server written in Ruby  
**Version:** 0.0.1  
**License:** MIT  
**Author:** Piotr Usewicz  
**Repository:** https://github.com/pusewicz/ruby-tak  

### Purpose
RubyTAK is a Ruby implementation of a TAK (Team Awareness Kit) server. TAK is a situational awareness platform used for tactical communications and coordination. This server enables TAK clients (like iTAK, ATAK, WinTAK) to connect, authenticate, and exchange CoT (Cursor on Target) messages.

## Architecture Overview

### Core Components

1. **CLI (`lib/ruby_tak/cli.rb`)** - 204 lines
   - Command-line interface for server operations
   - Certificate generation (CA and server certificates)
   - Server startup with optional port configuration
   - Uses OpenSSL for certificate generation

2. **Server (`lib/ruby_tak/server.rb`)** - 189 lines
   - TCP server listening on configurable port (default: 8089)
   - Multi-threaded connection handling (one thread per client)
   - Connection limits (MAX_CONNECTIONS = 200)
   - Connection timeout (CONNECTION_TIMEOUT = 300 seconds)
   - Message broadcasting and routing
   - Authentication using hardcoded credentials

3. **Client (`lib/ruby_tak/client.rb`)** - 55 lines
   - Represents a connected client
   - Manages socket I/O with timeouts
   - Buffers and extracts XML messages
   - Tracks client metadata (UID, callsign, group, activity)

4. **Message (`lib/ruby_tak/message.rb`)** - 86 lines
   - Wraps CoT XML messages
   - Parses and provides accessors for message data
   - Identifies message types (ping, ident, marti)
   - Handles Marti-style direct messaging

5. **MessageParser (`lib/ruby_tak/message_parser.rb`)** - 16 lines
   - Thin wrapper around Ox XML parser
   - Normalizes parsed XML to Ox::Element

6. **MessageBuilder (`lib/ruby_tak/message_builder.rb`)** - 87 lines
   - Constructs CoT XML messages
   - Provides helper for generating PONG responses
   - Handles XML document structure and attributes

7. **Configuration (`lib/ruby_tak/configuration.rb`)** - 76 lines
   - Manages server configuration
   - Uses XDG base directory specification for file locations
   - Certificate path management
   - Port validation

### Dependencies

**Runtime:**
- `ox` - Fast XML parser and builder
- `xdg` - XDG Base Directory support
- `zeitwerk` - Code autoloading

**Development:**
- `debug` - Ruby debugger
- `overcommit` - Git hooks management
- `rake` - Build tool
- `rubocop` - Linter (with minitest, performance, rake plugins)

**Test:**
- `minitest` - Testing framework
- `simplecov` - Code coverage

## Code Statistics

- **Total Ruby Files:** 20 (excluding vendor)
- **Test Files:** 14
- **Source Files:** 9 (in lib/)
- **Total Source Lines:** 719
- **Test Coverage:** 94.24% (687/729 lines)

### File Size Breakdown (lib/)
```
204 lines - lib/ruby_tak/cli.rb
189 lines - lib/ruby_tak/server.rb
 87 lines - lib/ruby_tak/message_builder.rb
 86 lines - lib/ruby_tak/message.rb
 76 lines - lib/ruby_tak/configuration.rb
 55 lines - lib/ruby_tak/client.rb
 42 lines - lib/ruby_tak.rb
 16 lines - lib/ruby_tak/message_parser.rb
  6 lines - lib/ruby_tak/version.rb
```

## Key Features

### Server Capabilities
- Multi-threaded client handling
- Broadcast messaging (one-to-many)
- Direct messaging via Marti protocol
- Connection timeout management
- Connection limit enforcement
- Ping/pong heartbeat mechanism

### Security Features
- Certificate-based authentication setup
- CA certificate generation
- Server certificate generation with proper X.509 extensions
- SSL/TLS ready (infrastructure in place)

### Message Types Handled
1. **Auth** - Client authentication
2. **Event** - General CoT events
3. **Ident** - Client identification
4. **Ping** - Heartbeat messages
5. **Marti** - Direct messaging

## Testing Infrastructure

### Test Files
1. `test/cli_test.rb` - 238 lines
2. `test/server_test.rb` - 439 lines
3. `test/configuration_test.rb` - 104 lines
4. `test/message_test.rb` - 44 lines
5. `test/message_builder_test.rb` - 17 lines
6. `test/ruby_tak_test.rb` - 7 lines

### Build & Test Commands
```bash
# Run tests
bundle exec rake test

# Run linter
bundle exec rake rubocop

# Run both (default)
bundle exec rake
```

## Code Quality

### Linting
- **Rubocop:** All files pass with 0 offenses
- **Plugins:** rubocop-performance, rubocop-rake, rubocop-minitest
- **Style:** Double quotes for strings
- **Target Ruby:** 3.4

### Code Conventions
- Frozen string literals in all files
- Module namespacing under `RubyTAK`
- Minitest for testing
- Thread-safe operations using Mutex
- Set for client collection management

## Current Issues

### 1. Ruby Version Mismatch (CRITICAL)
**Issue:** Code uses Ruby 3.4 syntax (`it` block parameter) but environment has Ruby 3.2.3

**Affected Files:**
- `lib/ruby_tak/message.rb:33` - `it.name == "dest"`
- `lib/ruby_tak/message.rb:39` - `it.name == "dest"` and `it.attributes[:uid]`
- `lib/ruby_tak/server.rb:131` - `it.uid == uid`

**Impact:** Test failure in `ServerTest#test_handle_event_with_marti_dest`

**Fix Required:** Either:
- Upgrade Ruby to 3.4+, OR
- Replace `it` with explicit block parameters (e.g., `|node|`)

### 2. Hardcoded Authentication
**Location:** `lib/ruby_tak/server.rb:8-10`
```ruby
USERS = {
  "piotr" => "password"
}.freeze
```

**Recommendation:** Move to configuration or external auth system for production use

### 3. Non-blocking I/O TODO
**Location:** `lib/ruby_tak/server.rb:30-31`
```ruby
# TODO: Make things non-blocking
# https://stackoverflow.com/questions/29858113/unable-to-make-socket-accept-non-blocking-ruby-2-2
```

**Impact:** Server uses blocking accept, limiting scalability

## Benchmarking Suite

The project includes comprehensive benchmarking tools in `/benchmarks`:

1. **concurrent_connections.rb** - Tests connection handling capacity
2. **message_throughput.rb** - Tests message processing performance
3. **benchmark_client.rb** - Reusable client for benchmarks
4. **run_benchmarks.rb** - Benchmark runner wrapper

## CI/CD

### GitHub Actions
- **Workflow:** `.github/workflows/ruby.yml`
- **Trigger:** Push to main, all PRs
- **Jobs:** 
  - Checkout code
  - Setup Ruby with bundler cache
  - Run `bundle exec rake` (tests + rubocop)

### Dependency Management
- **Dependabot:** Configured in `.github/dependabot.yml`

## Development Workflow

### Setup
```bash
git clone https://github.com/pusewicz/ruby-tak.git
cd ruby-tak
./bin/setup
```

### Usage
```bash
# Generate CA certificate
./exe/ruby_tak certificate ca

# Generate server certificate
./exe/ruby_tak certificate server

# Start server
./exe/ruby_tak server

# Start server on custom port
./exe/ruby_tak server --port 9000
```

## Architecture Patterns

### Thread Safety
- Uses `Mutex` for protecting shared client set
- Thread-per-client model
- Connection watchdog in separate thread

### Error Handling
- Socket errors caught (IOError, ECONNRESET, EPIPE)
- Timeout handling on writes
- Graceful client disconnection

### Message Flow
1. Client connects → TCP socket created
2. Server creates Client wrapper
3. Thread started for client
4. Messages read and buffered
5. Complete XML messages extracted
6. Messages parsed and handled
7. Response sent or broadcast performed

### Configuration Management
- XDG Base Directory Specification compliance
- Separate directories for config and data
- Environment variable support (PORT, DEBUG)

## Potential Improvements

1. **SSL/TLS Implementation** - Infrastructure present but not active
2. **Database Integration** - Currently in-memory only
3. **Configurable Authentication** - Replace hardcoded users
4. **Non-blocking I/O** - Improve scalability
5. **Message Persistence** - Store messages for replay
6. **Metrics/Monitoring** - Add instrumentation
7. **Docker Support** - Dockerfile/docker-compose ready
8. **API Documentation** - Document CoT message formats

## Dependencies Matrix

### Production Dependencies
- ox >= 2.14.23
- xdg >= 7.1.3 (downgraded from 9.5.0)
- zeitwerk >= 2.7.3

### Development Dependencies
- debug >= 1.11.0
- overcommit >= 0.68.0
- rake >= 13.3.1
- rubocop >= 1.81.7
- rubocop-minitest >= 0.38.2
- rubocop-performance >= 1.26.1
- rubocop-rake >= 0.7.1

### Test Dependencies
- minitest >= 5.26.2
- simplecov >= 0.22.0

## Security Considerations

1. **Certificate Management**
   - CA and server certificates generated with proper extensions
   - RSA 2048-bit keys (TAK compatible)
   - 10-year CA validity, 2-year server validity
   - Files stored with 0600 permissions

2. **Authentication**
   - Currently basic username/password
   - Authentication happens after connection
   - Failed auth results in disconnection

3. **Input Validation**
   - Port range validation (1-65535)
   - XML parsing with error handling
   - Connection limits to prevent resource exhaustion

## Project Structure
```
ruby-tak/
├── lib/
│   └── ruby_tak/
│       ├── cli.rb              # Command-line interface
│       ├── client.rb           # Client connection wrapper
│       ├── configuration.rb    # Configuration management
│       ├── message.rb          # Message wrapper
│       ├── message_builder.rb  # Message construction
│       ├── message_parser.rb   # XML parsing
│       ├── server.rb           # TCP server
│       └── version.rb          # Version constant
├── test/                       # Test suite
├── exe/                        # Executables
├── benchmarks/                 # Performance tests
├── .github/                    # CI configuration
└── [config files]             # Gemfile, Rakefile, etc.
```

## Conclusion

RubyTAK is a well-structured, clean implementation of a TAK server with:
- **Strengths:** Good test coverage, clean architecture, comprehensive benchmarking
- **Weaknesses:** Ruby version incompatibility, blocking I/O, hardcoded auth
- **Readiness:** Alpha/development stage (version 0.0.1)
- **Documentation:** Good README, extensive comments in complex areas

The codebase follows Ruby best practices and is ready for further development once the Ruby version issue is resolved.
