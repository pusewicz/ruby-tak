#!/bin/sh
set -e

if [ -z "$1" ]; then
  if [ -f "$HOME/.config/ruby_tak/certs/ruby_tak-server.p12" ]; then
    echo "Certificates already exists. Starting..."
  else
    echo "Certificates do not exist. Creating..."
    ./exe/ruby_tak certificate ca
    ./exe/ruby_tak certificate server
    ./exe/ruby_tak client --name user1
    ./exe/ruby_tak client --name user2
  fi
  exec ./exe/ruby_tak server --trace
else
  exec ./exe/ruby_tak "$@"
fi
