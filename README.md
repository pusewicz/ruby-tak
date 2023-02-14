# ruby-tak ![Main](https://github.com/pusewicz/ruby-tak/actions/workflows/ruby.yml/badge.svg) ![GitHub version](https://badge.fury.io/gh/pusewicz%2Fruby-tak.svg) ![Gem Version](https://badge.fury.io/rb/ruby-tak.svg)

RubyTAK—TAK server written in Ruby

## Quick start

  1. Clone the repository and enter the directory
  
         git clone https://github.com/pusewicz/ruby-tak.git
         cd ruby-tak
         
  2. Install depependencies
     
         ./bin/setup
         
  3. Create CA certificate

         ./exe/ruby_tak certificate ca
    
  4. Create Server certificate

         ./exe/ruby_tak certificate server
        
  5. Create iTAK connection data package
  
         ./exe/ruby_tak client
        
  6. Start the RubyTAK server
  
         ./exe/ruby_tak server
        
  7. Use the generated `client.zip` data package and load it into iTAK to connect to the server ([instructions](https://atakhq.com/en/itak/setup-guide#data-package-method)).

## Tests

Install dependencies:

    ./bin/setup
    
Run tests:

    bundle exec rake tests
