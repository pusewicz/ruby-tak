# frozen_string_literal: true

require "test_helper"

class MessageBuilderTest < Minitest::Test
  def test_pong
    now = Time.new(2023, 2, 9, 5, 34, 7, "Z")
    message = <<~XML.strip
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <event version="2.0" uid="takPong" type="t-x-c-t-r" how="h-g-i-g-o" time="2023-02-09T05:34:07.000Z" start="2023-02-09T05:34:07.000Z" stale="2023-02-09T05:34:27.000Z">
        <point lat="0" lon="0" hae="0" ce="9999999" le="9999999"/>
      </event>
    XML

    assert_equal message, RubyTAK::MessageBuilder.pong(now).strip
  end
end
