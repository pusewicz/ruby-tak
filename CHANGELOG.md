# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A certificate-enrollment API (`/Marti/api/tls/config`,
  `/Marti/api/tls/signClient/v2`, `/Marti/api/tls/profile/enrollment`) on a
  new port (`8446` by default, `ENROLLMENT_PORT` env override). TAK clients
  added as a "TAK Server" entry with a username and password — like iTAK —
  call this to trade credentials for a client certificate before streaming;
  without it, they failed with a generic authentication error and nothing in
  the server log.

### Fixed

- Pressing Ctrl-C now shuts the server down cleanly (disconnecting clients and
  closing the socket) instead of crashing with an unhandled `Interrupt`
  backtrace.

## [1.1.0] - 2026-09-15

### Changed

- Now requires Ruby >= 4.0.

### Fixed

- Runtime dependencies (`logger`, `ox`, `xdg`, `zeitwerk`) are now declared on
  the gem itself, so installing it pulls them in automatically.
- The server no longer crashes or drops a client's connection on malformed or
  unrecognized input: bad XML is logged and ignored, unknown message types are
  logged instead of killing the connection, and an auth message without a
  `<cot>` element disconnects the client cleanly instead of raising. A client's
  input buffer is now capped so it can't grow unbounded.

### Removed

- Docker, docker-compose, and Fly.io deployment files (unused for now).

## [1.0.0] - 2025-11-18

### Added

- Validate the command and display help.

[Unreleased]: https://github.com/pusewicz/ruby-tak/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/pusewicz/ruby-tak/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/pusewicz/ruby-tak/releases/tag/v1.0.0
