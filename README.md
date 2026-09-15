# ruby-tak ![Main](https://github.com/pusewicz/ruby-tak/actions/workflows/ruby.yml/badge.svg) ![GitHub version](https://badge.fury.io/gh/pusewicz%2Fruby-tak.svg) ![Gem Version](https://badge.fury.io/rb/ruby-tak.svg)

RubyTAK—TAK server written in Ruby

## Quick start

    git clone https://github.com/pusewicz/ruby-tak.git
    cd ruby-tak
    ./bin/setup
    ./exe/ruby_tak certificate ca
    ./exe/ruby_tak certificate server
    ./exe/ruby_tak client
    ./exe/ruby_tak server

Load the generated `client.zip` data package into iTAK to connect to the server ([instructions](https://atakhq.com/en/itak/setup-guide#data-package-method)).

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

## Development

    ./bin/setup
    ./bin/rake
