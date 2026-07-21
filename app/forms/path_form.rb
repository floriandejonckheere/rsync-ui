# frozen_string_literal: true

class PathForm < ApplicationForm
  NEW_SERVER = "new"

  attribute :path,
            :string

  attribute :server_id,
            :string

  attr_accessor :requires_server,
                :server_ids

  validates :path,
            presence: true

  validate :validate_server_id

  private

  def validate_server_id
    return unless requires_server

    if server_id.blank?
      errors.add(:server_id, :blank)
    elsif server_id != NEW_SERVER && server_ids.exclude?(server_id)
      errors.add(:server_id, :invalid)
    end
  end
end
