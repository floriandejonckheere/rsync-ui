# frozen_string_literal: true

puts "Seeding jobs..."

Jobs::ImportService.call(path: Rails.root.join("db/seeds/development"))

puts "  Done."
