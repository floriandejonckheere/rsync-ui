# frozen_string_literal: true

RSpec.describe "Registrations" do
  describe "POST /users" do
    let(:valid_params) do
      {
        user: {
          first_name: "Test",
          last_name: "User",
          email: "test@example.com",
          password: "password123",
          password_confirmation: "password123",
        },
      }
    end

    it "creates a user" do
      expect { post user_registration_path, params: valid_params }
        .to change(User, :count).by(1)
    end
  end
end
