# frozen_string_literal: true

puts "Seeding hooks..."

Hooks::ImportService.call(path: Rails.root.join("db/seeds/development"))

puts "  Done."
