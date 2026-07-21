# frozen_string_literal: true

class JobForm < ApplicationForm
  SYNC_TYPES = [
    "local_to_local",
    "local_to_remote",
    "remote_to_local",
  ].freeze

  attribute :name,
            :string

  attribute :description,
            :string

  attribute :sync_type,
            :string

  attribute :source_path,
            :string

  attribute :source_server_id,
            :string

  attribute :destination_path,
            :string

  attribute :destination_server_id,
            :string

  validates :name,
            presence: true

  validates :sync_type,
            inclusion: { in: SYNC_TYPES }

  def remote_to_local? = sync_type == "remote_to_local"
  def local_to_remote? = sync_type == "local_to_remote"
  def local_to_local? = sync_type == "local_to_local"
  def remote_repo? = !local_to_local?

  def basics_complete? = name.present? && sync_type.present?
  def source_complete? = source_path.present? && (!remote_to_local? || source_server_id.present?)
  def source_server_complete? = source_server_id != PathForm::NEW_SERVER
  def destination_complete? = destination_path.present? && (!local_to_remote? || destination_server_id.present?)
  def destination_server_complete? = destination_server_id != PathForm::NEW_SERVER
  def schedule_complete? = true
end
