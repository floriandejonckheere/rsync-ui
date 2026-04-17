# frozen_string_literal: true

puts "Seeding users..."

Import::UserService.call(path: Rails.root.join("db/seeds/development"))

puts "  Done."
