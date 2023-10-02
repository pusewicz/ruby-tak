# frozen_string_literal: true

module RubyTAK
  class MessageBuilder
    def self.pong(now = Time.now.utc)
      # PING
      # <?xml version=\"1.0\"?>\n<event version=\"2.0\" uid=\"ANDROID-82cd68af1fb8fd80-ping\" type=\"t-x-c-t\" time=\"2023-10-02T05:33:17.731Z\" start=\"2023-10-02T05:33:17.731Z\" stale=\"2023-10-02T05:33:27.731Z\" how=\"m-g\">
      # <point lat=\"0.00000000\" lon=\"0.00000000\" hae=\"0.00000000\" ce=\"9999999\" le=\"9999999\"/><detail/>
      # </event>
      build({
              uid: "takPong",
              type: "t-x-c-t-r",
              how: "h-g-i-g-o",
              time: now,
              start: now,
              stale: (now + 20)
            })
    end

    def initialize(attributes = {}, tag: "event", point: nil, detail: nil)
      @attributes = attributes
      @tag = tag
      @point = point || { lat: 0, lon: 0, hae: 0, ce: 9_999_999, le: 9_999_999 }
      @detail = detail || {}
    end

    def to_xml
      Ox.dump(ox_document do |doc|
        doc << ox_element(@tag) do |e|
          @attributes.each do |k, v|
            e[k] = if v.is_a?(Time)
                     v.iso8601(3)
                   else
                     v
                   end
          end
        end
      end).strip
    end

    def self.build(attributes = {}, tag: "event", point: nil, detail: nil)
      new(attributes, tag:, point:, detail:).to_xml
    end

    private

    def build_point
      Ox::Element.new("point").tap do |e|
        @point.each do |k, v|
          e[k] = v
        end
      end
    end

    def build_detail
      Ox::Element.new("detail").tap do |e|
        @detail.each do |k, v|
          e[k] = v
        end
      end
    end

    def ox_document
      Ox::Document.new.tap do |doc|
        doc << ox_instruct
        yield doc if block_given?
      end
    end

    def ox_element(tag = "event")
      Ox::Element.new(tag).tap do |e|
        e[:version] = "2.0"

        yield e if block_given?

        e << build_point unless @point.empty?
        e << build_detail unless @detail.empty?
      end
    end

    def ox_instruct
      Ox::Instruct.new(:xml).tap do |i|
        i[:version] = "1.0"
        i[:encoding] = "UTF-8"
        i[:standalone] = "yes"
      end
    end
  end
end
