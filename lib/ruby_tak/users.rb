# frozen_string_literal: true

module RubyTAK
  module Users
    CREDENTIALS = {
      "piotr" => "password"
    }.freeze

    def authenticate?(username, password)
      CREDENTIALS[username] == password
    end
    module_function :authenticate?
  end
end
