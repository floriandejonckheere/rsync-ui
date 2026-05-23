# frozen_string_literal: true

module Tasks
  class ImportService < ::ImportService
    private

    def csv_filename
      "02_tasks.csv"
    end

    def import(row)
      Task
        .create_with(
          class_name: row["class_name"],
          configuration: row["configuration"].presence,
        )
        .find_or_create_by!(name: row["name"])
    end
  end
end
