# GitHub Copilot Instructions for RubyTAK

## Project Overview

RubyTAK is a TAK (Team Awareness Kit) server written in Ruby. It provides secure SSL/TLS communication for TAK clients, certificate management, and CoT (Cursor on Target) message handling.

## Language and Version

- **Language**: Ruby
- **Version**: 3.4.7 (minimum 3.4 required)
- Uses `frozen_string_literal: true` in all Ruby files
- Uses Zeitwerk for autoloading

## Build and Test Commands

### Setup
```bash
./bin/setup
```

### Run Tests
```bash
./bin/rake test
# or
bundle exec rake test
```

### Run Linting
```bash
./bin/rake rubocop
# or
bundle exec rake rubocop
```

### Run All Checks (default)
```bash
./bin/rake
# or
bundle exec rake
```
This runs both tests and RuboCop.

## Coding Conventions

### Style Guidelines

1. **String Literals**: Always use double quotes for strings
   ```ruby
   # Good
   "hello world"
   
   # Bad
   'hello world'
   ```

2. **String Interpolation**: Use double quotes in interpolation
   ```ruby
   # Good
   "Hello #{name}"
   ```

3. **Frozen String Literal**: All Ruby files must start with:
   ```ruby
   # frozen_string_literal: true
   ```

4. **Documentation**: Class and method documentation is not required (Style/Documentation is disabled)

5. **Naming**: 
   - Use `RubyTAK` for the module name (not `RubyTak` or `Ruby_Tak`)
   - Use `CLI` in uppercase (not `Cli`)

### RuboCop Configuration

- Target Ruby version: 3.4
- NewCops enabled
- Line length limits disabled
- Method length, ABC size, cyclomatic complexity, and perceived complexity metrics disabled
- Class length limits disabled
- Minitest: Maximum 5 assertions per test

### Testing

- Testing framework: Minitest
- Test helper location: `test/test_helper.rb`
- Test files: `test/**/*_test.rb`
- Code coverage: SimpleCov is enabled
- Use `setup` method for test initialization
- Maximum 5 assertions per test (can be adjusted if needed)

## Project Structure

```
lib/
  ruby_tak/
    cli.rb              # Command-line interface
    client.rb           # Client data package generation
    configuration.rb    # Configuration management
    message.rb          # CoT message representation
    message_builder.rb  # CoT message builder
    message_parser.rb   # CoT message parser
    server.rb           # TCP/SSL server implementation
    version.rb          # Version constant
  ruby_tak.rb           # Main entry point with Zeitwerk setup

test/
  *_test.rb             # Test files corresponding to lib files
  test_helper.rb        # Test configuration and setup

exe/
  ruby_tak              # Executable entry point

.github/
  workflows/
    ruby.yml            # CI workflow (runs rake default task)
```

## Dependencies

Key dependencies include:
- `zeitwerk` - Autoloading
- `ox` - Fast XML parsing
- `xdg` - XDG Base Directory specification
- `minitest` - Testing framework
- `rubocop` - Linting (with performance, rake, and minitest plugins)
- `simplecov` - Code coverage

## Configuration

- Configuration uses XDG Base Directory specification
- Default configuration directory: `~/.config/ruby_tak/`
- Certificates stored in: `~/.config/ruby_tak/certs/`
- Data packages stored in: `~/.local/share/ruby_tak/data_packages/`
- Default CoT SSL port: 8089

## Key Features

1. **Certificate Management**: CA and server certificate generation
2. **SSL/TLS Server**: Secure communication on configurable port
3. **CoT Message Handling**: Parsing and building Cursor on Target messages
4. **Client Data Packages**: iTAK connection package generation
5. **CLI**: User-friendly command-line interface using Thor-like pattern

## Development Workflow

1. Make changes to code
2. Run tests: `./bin/rake test`
3. Run linter: `./bin/rake rubocop`
4. Ensure both pass before committing

## CI/CD

- GitHub Actions workflow runs on push to main and on pull requests
- Workflow runs `bundle exec rake` (tests + RuboCop)
- Ruby is set up with bundler cache enabled

## Important Notes

- All paths should use `Pathname` for file system operations
- Logger is available via `RubyTAK.logger`
- Configuration is available via `RubyTAK.configuration`
- Thread-safe access to shared resources using `Mutex`
- Use `Socket.gethostname` for hostname detection
