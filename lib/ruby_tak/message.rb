# frozen_string_literal: true

# https://gist.github.com/a-f-G-U-C/77fed4e7aea38e27f3c50583e840a35b

module RubyTAK
  class Message < String
    extend Forwardable

    def_delegators :parsed_message, :name, :attributes, :nodes, :detail

    IDENT_KEYS = %w[__group contact takv].freeze

    def initialize(*)
      super
      @parsed_message = nil
    end

    def event?
      parsed_message.name == "event"
    end

    def ping?
      return false unless event?

      parsed_message.attributes[:type] == "t-x-c-t"
    end

    def marti?
      return false unless parsed_message.respond_to?(:detail)
      return false unless parsed_message.detail.respond_to?(:marti)
      return false unless parsed_message.detail.marti.nodes.size.positive?

      parsed_message.detail.marti.nodes.filter { _1.name == "dest" }.size.positive?
    end

    def marti_dest_uids
      return unless marti?

      parsed_message.detail.marti.nodes.filter { _1.name == "dest" }.map { _1.attributes[:uid] }
    end

    def contact
      return unless parsed_message.respond_to?(:detail)
      return unless parsed_message.detail.respond_to?(:contact)

      parsed_message.detail.contact
    end

    def cot
      return unless parsed_message.respond_to?(:cot)

      parsed_message.cot
    end

    def group
      return unless parsed_message.respond_to?(:detail)
      return unless parsed_message.detail.respond_to?(:__group)

      parsed_message.detail.__group
    end

    def ident?
      return false unless parsed_message.respond_to?(:detail)

      (parsed_message.detail.nodes.map(&:name) & IDENT_KEYS).sort == IDENT_KEYS
    end

    def to_xml
      Ox.dump(parsed_message)
    end

    private

    def parsed_message
      @parsed_message ||= begin
        message = MessageParser.parse(to_s)

        if message.respond_to?(:root)
          message.root
        else
          message
        end
      end
    end
  end
end
