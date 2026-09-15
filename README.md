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

## Development

    ./bin/setup
    ./bin/rake
