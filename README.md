# ruby-tak ![Main](https://github.com/pusewicz/ruby-tak/actions/workflows/ruby.yml/badge.svg) ![GitHub version](https://badge.fury.io/gh/pusewicz%2Fruby-tak.svg) ![Gem Version](https://badge.fury.io/rb/ruby-tak.svg)

RubyTAK—TAK server written in Ruby

## Quick start

    git clone https://github.com/pusewicz/ruby-tak.git
    cd ruby-tak
    ./bin/setup
    ./exe/ruby_tak certificate ca
    ./exe/ruby_tak certificate server
    ./exe/ruby_tak qr
    ./exe/ruby_tak server

Scan the QR code in iTAK (**Add Server → QR**) to add the server connection, then import the client certificate into iTAK separately.

## Development

    ./bin/setup
    ./bin/rake
