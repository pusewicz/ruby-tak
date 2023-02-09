# frozen_string_literal: true

# https://gist.github.com/a-f-G-U-C/77fed4e7aea38e27f3c50583e840a35b

module RubyTAK
  class Message
    IDENT_KEYS = %w[__group contact takv].freeze

    def initialize(message)
      @message = message
    end

    def event?
      @message.name == "event"
    end

    def ping?
      return unless event?

      @message.attributes[:type] == "t-x-c-t"
    end

    def marti?
      return unless @message.respond_to?(:detail)
      return unless @message.detail.respond_to?(:marti)
      return unless @message.detail.marti.nodes.size.positive?

      @message.detail.marti.nodes.filter { _1.name == "dest" }.size.positive?
    end

    def marti_dest_uids
      return unless marti?

      @message.detail.marti.nodes.filter { _1.name == "dest" }.map { _1.attributes[:uid] }
    end

    def attributes
      @message.attributes
    end

    def contact
      return unless @message.respond_to?(:detail)
      return unless @message.detail.respond_to?(:contact)

      @message.detail.contact
    end

    def group
      return unless @message.respond_to?(:detail)
      return unless @message.detail.respond_to?(:__group)

      @message.detail.__group
    end

    def self.from_ox_element(event)
      new(event).freeze
    end

    def ident?
      return unless @message.respond_to?(:detail)

      (@message.detail.nodes.map(&:name) & IDENT_KEYS).sort == IDENT_KEYS
    end

    def to_xml
      Ox.dump(@message)
    end
  end
end
