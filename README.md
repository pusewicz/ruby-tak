# ruby-tak ![Main](https://github.com/pusewicz/ruby-tak/actions/workflows/ruby.yml/badge.svg) ![GitHub version](https://badge.fury.io/gh/pusewicz%2Fruby-tak.svg) ![Gem Version](https://badge.fury.io/rb/ruby-tak.svg)

RubyTAK—TAK server written in Ruby

## Quick start

    git clone https://github.com/pusewicz/ruby-tak.git
    cd ruby-tak
    ./bin/setup
    ./exe/ruby_tak certificate ca
    ./exe/ruby_tak certificate server
    ./exe/ruby_tak server

See "Trusting the certificate" below to connect a TAK client to the server.

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

If the host's IP address changes (e.g. a new DHCP lease on a Raspberry
Pi), the server certificate no longer covers it and `certificate server`
won't regenerate it automatically — delete `ruby_tak-server.crt` and
`ruby_tak-server.key` and re-run `./exe/ruby_tak certificate server`.

## Connecting from iTAK

Add RubyTAK in iTAK as a **TAK Server**:

- **Server address**: the host's IP or hostname
- **Port**: `8089`
- **Username** / **Password**: `piotr` / `password`

## Development

    ./bin/setup
    ./bin/rake
