# frozen_string_literal: true

class ExportService < ApplicationService
  attr_reader :path

  def initialize(path:)
    super()

    @path = Pathname.new(path)
  end

  def call
    CSV.open(path.join(csv_filename), "w") do |csv|
      csv << headers

      rows.each { |row| csv << row }
    end
  end

  private

  def csv_filename
    "#{self.class.name.demodulize.delete_suffix('Service').underscore.pluralize}.csv"
  end

  def headers
    raise NotImplementedError
  end

  def rows
    raise NotImplementedError
  end
end
