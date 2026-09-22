# frozen_string_literal: true

require "test_helper"

class UsersTest < Minitest::Test
  def test_authenticate_accepts_correct_credentials
    assert RubyTAK::Users.authenticate?("rubytak", "password")
  end

  def test_authenticate_rejects_wrong_password
    refute RubyTAK::Users.authenticate?("rubytak", "wrong")
  end

  def test_authenticate_rejects_unknown_username_with_nil_password
    refute RubyTAK::Users.authenticate?("nobody", nil)
  end

  def test_authenticate_rejects_nil_username_and_nil_password
    refute RubyTAK::Users.authenticate?(nil, nil)
  end
end
