# frozen_string_literal: true

module RubyTAK
  class MessageBuilder
    def self.pong(now = Time.now.utc)
      build({

              uid: "takPong",
              type: "t-x-c-t-r",
              how: "h-g-i-g-o",
              time: now.iso8601,
              start: now.iso8601,
              stale: (now + 20).iso8601
            })
    end

    def self.build(attributes = {}, tag: "event")
      Ox.dump(ox_document do |doc|
        doc << ox_element(tag) do |e|
          attributes.each { |k, v| e[k] = v }
        end
      end).strip
    end

    def self.ox_document
      Ox::Document.new.tap do |doc|
        yield doc if block_given?
      end
    end

    def self.ox_element(tag = "event")
      Ox::Element.new(tag).tap do |e|
        e[:version] = "2.0"

        yield e if block_given?
      end
    end
  end
end
