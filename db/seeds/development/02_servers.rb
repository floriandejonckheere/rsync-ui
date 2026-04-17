# frozen_string_literal: true

puts "Seeding servers..."

Import::ServerService.call(path: Rails.root.join("db/seeds/development"))

puts "  Done."
