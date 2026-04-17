# frozen_string_literal: true

# Find or create user
user = User.find_or_initialize_by(email: ENV.fetch("ADMIN_EMAIL", ""))

user.update!(
  first_name: "Admin",
  last_name: "Administrator",
  password: ENV.fetch("ADMIN_PASSWORD", ""),
  role: "admin",
)
