# frozen_string_literal: true

puts "Seeding notifications..."

Notifications::ImportService.call(path: Rails.root.join("db/seeds/development"))

puts "  Done."
