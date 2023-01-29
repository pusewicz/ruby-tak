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

# <?xml version="1.0" encoding="utf-8" standalone="yes"?>
# <event version="2.0" uid="FBE5C615-2EC8-427D-8178-E2DD9716E361" type="a-f-G-E-V-C" how="h-e" time="2023-01-24T09:17:49Z" start="2023-01-24T09:17:49Z" stale="2023-01-24T09:19:49Z">
#     <point lat="40.41592833093477" lon="0.42432347628362926" hae="0.0" ce="9999999.0" le="9999999.0"/>
#     <detail>
#         <contact callsign="Papa Uniform macOS" phone="" endpoint="*:-1:stcp"/>
#         <__group name="Cyan" role="Team Member"/>
#         <precisionlocation geopointsrc="User" altsrc="???"/>
#         <status battery="100"/>
#         <takv device="iPad" platform="iTAK" os="16.2" version="2.4.1.602"/>
#         <track speed="-1.0" course="0.0"/>
#         <uid Droid="Papa Uniform macOS"/>
#     </detail>
# </event>
