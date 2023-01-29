# frozen_string_literal: true

require "test_helper"

class EventDetailContactTest < Minitest::Test
  def test_to_ox_element
    contact = RubyTAK::EventDetail::Contact.new(callsign: "N0CALL", phone: "555-555-5555", endpoint: "*:-1:stcp")

    assert_equal <<~XML.strip, Ox.dump(contact.to_ox_element).strip
      <contact callsign="N0CALL" phone="555-555-5555" endpoint="*:-1:stcp"/>
    XML
  end
end
