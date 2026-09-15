# frozen_string_literal: true

require "rqrcode_core"

module RubyTAK
  class QRCode
    QUIET_ZONE = 4
    BLOCKS = {
      [true, true] => "█",
      [true, false] => "▀",
      [false, true] => "▄",
      [false, false] => " "
    }.freeze

    def initialize(data, level: :m)
      @qr = RQRCodeCore::QRCode.new(data, level: level)
    end

    def to_terminal
      padded_modules.each_slice(2).map do |top, bottom|
        bottom ||= Array.new(top.size, false)
        "\e[30;47m#{top.zip(bottom).map { |pair| BLOCKS[pair] }.join}\e[0m"
      end.join("\n")
    end

    private

    def padded_modules
      padding = Array.new(QUIET_ZONE, false)
      padded = @qr.modules.map { |row| padding + row + padding }
      blank_row = Array.new(padded.first.size, false)
      Array.new(QUIET_ZONE) { blank_row } + padded + Array.new(QUIET_ZONE) { blank_row }
    end
  end
end
