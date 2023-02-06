# frozen_string_literal: true

require "test_helper"

class MessageTest < Minitest::Test
  XML = <<~XML
    <event version="2.0" uid="FBE5C615-2EC8-427D-8178-E2DD9716E361" type="a-f-G-E-V-C" how="h-e" time="2023-01-24T09:17:49Z" start="2023-01-24T09:17:49Z" stale="2023-01-24T09:19:49Z">
      <point lat="40.41592833093477" lon="0.42432347628362926" hae="0.0" ce="9999999.0" le="9999999.0"/>
      <detail>
        <contact callsign="Papa Uniform" phone="+34123456789" endpoint="*:-1:stcp"/>
        <__group name="Cyan" role="Team Member"/>
        <precisionlocation geopointsrc="User" altsrc="???"/>
        <status battery="100"/>
        <takv device="iPad" platform="iTAK" os="16.2" version="2.4.1.602"/>
        <track speed="-1.0" course="0.0"/>
        <uid Droid="Papa Uniform macOS"/>
      </detail>
    </event>
  XML

  def test_from_ox_element
    message = RubyTAK::Message.from_ox_element(RubyTAK::MessageParser.parse(XML))

    assert_equal(
      { version: "2.0", uid: "FBE5C615-2EC8-427D-8178-E2DD9716E361", type: "a-f-G-E-V-C", how: "h-e",
        time: "2023-01-24T09:17:49Z", start: "2023-01-24T09:17:49Z", stale: "2023-01-24T09:19:49Z" }, message.attributes
    )
  end

  def test_to_xml
    message = RubyTAK::Message.from_ox_element(RubyTAK::MessageParser.parse(XML))

    assert_equal XML.strip, message.to_xml.strip
  end
end