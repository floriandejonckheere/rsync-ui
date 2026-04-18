# frozen_string_literal: true

puts "Seeding job runs..."

Import::JobRunService.call(path: Rails.root.join("db/seeds/development"))

puts "  Done."
