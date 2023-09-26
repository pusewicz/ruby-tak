#!/bin/sh
set -e

if [ -z "$1" ]; then
  echo "Starting RubyTak server..."
  exec ./exe/ruby_tak server --trace
else
  echo "Running RubyTak command... $@"
  exec ./exe/ruby_tak "$@"
fi
