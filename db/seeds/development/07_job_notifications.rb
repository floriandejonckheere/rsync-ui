# frozen_string_literal: true

puts "Seeding job notifications..."

JobNotifications::ImportService.call(path: Rails.root.join("db/seeds/development"))

puts "  Done."
