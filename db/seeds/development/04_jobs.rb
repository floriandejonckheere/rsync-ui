# frozen_string_literal: true

puts "Seeding jobs..."

Import::JobService.call(path: Rails.root.join("db/seeds/development"))

puts "  Done."
