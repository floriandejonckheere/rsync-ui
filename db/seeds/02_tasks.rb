# frozen_string_literal: true

puts "Seeding tasks..."

Tasks::ImportService.call(path: Rails.root.join("db/seeds"))

puts "  Done."
