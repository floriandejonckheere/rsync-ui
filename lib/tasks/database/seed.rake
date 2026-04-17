# frozen_string_literal: true

namespace :database do
  desc "Seed production and development database"
  task seed: ["seed:production", "seed:development"]

  namespace :seed do
    desc "Seed production database"
    task production: :environment do
      Rails.root.glob("db/seeds/*.rb").each { |f| require f }
    end

    desc "Seed development database"
    task development: :environment do
      Rails.root.glob("db/seeds/development/*.rb").each { |f| require f }
    end
  end
end
