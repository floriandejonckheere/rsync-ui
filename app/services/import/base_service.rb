# frozen_string_literal: true

module Import
  class BaseService < ApplicationService
    attr_reader :path

    def initialize(path:)
      super()

      @path = Pathname.new(path)
    end

    def call
      file = path.join(csv_filename)

      return unless file.exist?

      CSV.foreach(file, headers: true) do |row|
        import(row)
      end
    end

    private

    def csv_filename
      "#{self.class.name.demodulize.delete_suffix('Service').underscore.pluralize}.csv"
    end

    def import(_row)
      raise NotImplementedError
    end
  end
end
