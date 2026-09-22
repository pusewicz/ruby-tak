# frozen_string_literal: true

module RubyTAK
  module Users
    CREDENTIALS = {
      "rubytak" => "password"
    }.freeze

    def authenticate?(username, password)
      return false if password.nil?

      CREDENTIALS[username] == password
    end
    module_function :authenticate?
  end
end
