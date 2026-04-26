# frozen_string_literal: true

puts "Seeding users..."

Users::ImportService.call(path: Rails.root.join("db/seeds/development"))

puts "  Done."
