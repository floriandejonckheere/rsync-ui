# frozen_string_literal: true

puts "Seeding repositories..."

Import::RepositoryService.call(path: Rails.root.join("db/seeds/development"))

puts "  Done."
