# frozen_string_literal: true

require "test_helper"

class QRCodeTest < Minitest::Test
  def setup
    @output = RubyTAK::QRCode.new("RubyTAK,tak.example.com,8089,ssl").to_terminal
  end

  def test_to_terminal_contains_block_characters
    assert_match(/█/, @output)
  end

  def test_to_terminal_wraps_every_line_in_color_codes
    lines = @output.split("\n")

    assert(lines.all? { |line| line.start_with?("\e[30;47m") && line.end_with?("\e[0m") })
  end

  def test_to_terminal_pairs_module_rows_into_half_as_many_lines
    modules = RQRCodeCore::QRCode.new("RubyTAK,tak.example.com,8089,ssl", level: :m).modules
    padded_row_count = modules.size + (RubyTAK::QRCode::QUIET_ZONE * 2)

    assert_equal (padded_row_count / 2.0).ceil, @output.split("\n").size
  end
end
