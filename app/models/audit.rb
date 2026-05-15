# frozen_string_literal: true

class Audit < ApplicationRecord
  belongs_to :server

  validates :command,
            presence: true

  validates :started_at,
            presence: true

  scope :by_server,
        ->(server_id) { where(server_id:) if server_id.present? }

  scope :completed,
        -> { where(exit_status: 0) }

  scope :failed,
        -> { where.not(exit_status: 0) }

  scope :started_from,
        ->(from) { where(started_at: from..) if from.present? }

  scope :started_to,
        ->(to) { where(started_at: ..to) if to.present? }
end

# == Schema Information
#
# Table name: audits
#
#  id           :uuid             not null, primary key
#  command      :text             not null
#  completed_at :datetime
#  exit_status  :integer          indexed
#  output       :text             default(""), not null
#  started_at   :datetime         not null, indexed
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  server_id    :uuid             not null, indexed
#
# Indexes
#
#  index_audits_on_exit_status  (exit_status)
#  index_audits_on_server_id    (server_id)
#  index_audits_on_started_at   (started_at)
#
# Foreign Keys
#
#  fk_rails_...  (server_id => servers.id) ON DELETE => cascade
#
