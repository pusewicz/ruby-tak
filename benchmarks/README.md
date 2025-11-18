# RubyTAK Benchmarks

Benchmark scripts for profiling and testing RubyTAK server performance.

## Prerequisites

1. Start a RubyTAK server:
   ```bash
   cd ..
   ./exe/ruby_tak server
   ```

2. Run benchmarks from this directory

## Available Benchmarks

### Concurrent Connections
Tests how the server handles many simultaneous client connections.

```bash
# Default: 100 clients
ruby concurrent_connections.rb

# Custom number of clients
ruby concurrent_connections.rb 200

# Custom host and port
ruby concurrent_connections.rb 150 192.168.1.100 8089
```

**Phases:**
1. Connect all clients
2. Authenticate
3. Send ident messages
4. Send ping messages
5. Hold connections for 10 seconds
6. Disconnect all clients

**Metrics:**
- Connection success rate
- Total messages sent/received
- Bytes sent/received
- Messages per second
- Errors

### Message Throughput
Tests how many messages per second the server can handle.

```bash
# Default: 50 clients, 30 seconds, 10 msgs/sec per client
ruby message_throughput.rb

# Custom: 100 clients, 60 seconds, 20 msgs/sec per client
ruby message_throughput.rb 100 60 20

# Full custom
ruby message_throughput.rb 100 60 20 localhost 8089
```

**Parameters:**
- `num_clients`: Number of concurrent clients
- `duration`: How long to run (seconds)
- `message_rate`: Messages per second per client
- `host`: Server hostname
- `port`: Server port

**Metrics:**
- Total messages sent/received
- Messages per second
- Throughput (bytes/sec)
- Average per client
- Errors

### Benchmark Runner
Convenient wrapper to run all benchmarks or specific ones.

```bash
# List available benchmarks
ruby run_benchmarks.rb --list

# Run all benchmarks
ruby run_benchmarks.rb

# Run specific benchmark
ruby run_benchmarks.rb -b connections
ruby run_benchmarks.rb -b throughput

# Custom server
ruby run_benchmarks.rb -h 192.168.1.100 -p 8089
```

## Profiling

Use these benchmarks with Ruby profilers:

### ruby-prof
```bash
gem install ruby-prof

# Profile concurrent connections
ruby-prof concurrent_connections.rb 100

# Generate call graph
ruby-prof --printer=graph concurrent_connections.rb 100 > profile.txt
```

### stackprof
```bash
gem install stackprof

# Profile with stackprof
stackprof --mode=cpu --out=tmp/stackprof.dump -- concurrent_connections.rb 100

# View results
stackprof tmp/stackprof.dump
```

### memory_profiler
```bash
gem install memory_profiler

# Profile memory usage
ruby -r memory_profiler -e "MemoryProfiler.report { load 'concurrent_connections.rb' }.pretty_print"
```

## Understanding Results

### Connection Benchmark
- **Max connections test**: Increase clients until server rejects (100 limit by default)
- **Connection timeout test**: Leave connections idle to test 300s timeout

### Throughput Benchmark
- **Broadcast load**: Each message is broadcast to all other clients
- **Expected load**: num_clients × message_rate × (num_clients - 1) broadcasts/sec
- **Example**: 50 clients @ 10 msg/sec = 500 sends → 24,500 broadcasts/sec

## Tips

1. **Start small**: Begin with 10-20 clients to verify everything works
2. **Monitor server**: Watch CPU, memory, and thread count on server
3. **Network limits**: Local testing avoids network bottlenecks
4. **File descriptors**: May need to increase ulimit for many connections
5. **Thread limit**: Server creates one thread per client

## Example Session

```bash
# Terminal 1: Start server
cd ..
./exe/ruby_tak server

# Terminal 2: Run benchmarks
cd benchmarks

# Quick test
ruby concurrent_connections.rb 10

# Full connection test
ruby concurrent_connections.rb 150

# Throughput test
ruby message_throughput.rb 50 30 10

# Profile with ruby-prof
ruby-prof --printer=flat --min-percent=1 concurrent_connections.rb 100
```
