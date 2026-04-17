# frozen_string_literal: true

# Silence ActiveRecord SQL logging during db:* tasks
["db:create", "db:drop", "db:migrate", "db:rollback", "db:seed", "db:schema:load", "db:schema:dump", "db:test:prepare", "database:seed", "database:seed:production", "database:seed:development"].each do |task|
  Rake::Task[task].enhance(["db:silence_logger"])
end

namespace :db do
  task silence_logger: :environment do
    ActiveRecord::Base.logger = nil
  end
end
