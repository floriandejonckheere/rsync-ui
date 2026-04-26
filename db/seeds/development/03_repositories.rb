# frozen_string_literal: true

puts "Seeding repositories..."

Repositories::ImportService.call(path: Rails.root.join("db/seeds/development"))

puts "  Done."
