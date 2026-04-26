# frozen_string_literal: true

puts "Seeding servers..."

Servers::ImportService.call(path: Rails.root.join("db/seeds/development"))

puts "  Done."
