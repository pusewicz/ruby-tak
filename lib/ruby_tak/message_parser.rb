# frozen_string_literal: true

require "ox"

module RubyTAK
  module MessageParser
    def parse(data)
      parsed_data = Ox.parse(data)

      # Always return an Ox::Element, even if we have a full document that contains <?xml instruct
      parsed_data = parsed_data.root if parsed_data.respond_to?(:root)
      parsed_data
    end
    module_function :parse
  end
end
