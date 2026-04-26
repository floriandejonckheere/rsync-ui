# frozen_string_literal: true

puts "Seeding job runs..."

JobRuns::ImportService.call(path: Rails.root.join("db/seeds/development"))

puts "  Done."
