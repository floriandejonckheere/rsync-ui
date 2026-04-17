# frozen_string_literal: true

module Export
  class UserService < BaseService
    private

    def headers = ["first_name", "last_name", "email", "password", "role"]

    def rows
      User.all.map do |user|
        [
          user.first_name,
          user.last_name,
          user.email,
          "password", # Only password hash is stored
          user.role,
        ]
      end
    end
  end
end
