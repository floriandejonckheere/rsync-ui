# frozen_string_literal: true

class Notification < ApplicationRecord
  encrypts :url

  belongs_to :user

  has_many :job_notifications,
           dependent: :destroy

  has_many :jobs,
           through: :job_notifications

  validates :name,
            presence: true

  validates :url,
            presence: true

  validate :url_has_scheme

  private

  def url_has_scheme
    return if url.blank?

    parsed = URI.parse(url)
    errors.add(:url, :invalid) if parsed.scheme.blank?
  rescue URI::InvalidURIError
    errors.add(:url, :invalid)
  end
end

# == Schema Information
#
# Table name: notifications
#
#  id          :uuid             not null, primary key
#  description :text
#  enabled     :boolean          default(TRUE), not null
#  name        :string           not null
#  url         :text             not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :uuid             not null, indexed
#
# Indexes
#
#  index_notifications_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
