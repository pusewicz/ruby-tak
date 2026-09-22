# frozen_string_literal: true

module RubyTAK
  module Users
    CREDENTIALS = {
      "piotr" => "password"
    }.freeze

    def authenticate?(username, password)
      return false if password.nil?

      CREDENTIALS[username] == password
    end
    module_function :authenticate?
  end
end
