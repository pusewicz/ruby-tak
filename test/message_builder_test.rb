# frozen_string_literal: true

require "test_helper"

class MessageBuilderTest < Minitest::Test
  def test_pong
    now = Time.new(2023, 2, 9, 5, 34, 7, "Z")
    message = %(<event version="2.0" uid="takPong" type="t-x-c-t-r" how="h-g-i-g-o" time="2023-02-09T05:34:07Z" start="2023-02-09T05:34:07Z" stale="2023-02-09T05:34:27Z"/>)

    assert_equal message, RubyTAK::MessageBuilder.pong(now).strip
  end
end
