# frozen_string_literal: true

class Repository < ApplicationRecord
  enum :repository_type, { local: "local", remote: "remote" }, validate: true

  belongs_to :user
  belongs_to :server,
             optional: true

  validates :name,
            presence: true

  validates :path,
            presence: true

  validates :server,
            presence: true,
            if: :remote?

  validates :server,
            absence: true,
            if: :local?

  # validate :server_presence_for_remote
  # validate :server_absence_for_local

  # def server_presence_for_remote
  #   return unless repository_type.present? && remote?
  #
  #   errors.add(:server, :blank) if server.nil?
  # end
  #
  # def server_absence_for_local
  #   return unless repository_type.present? && local?
  #
  #   errors.add(:server, :present) if server.present?
  # end
end

# == Schema Information
#
# Table name: repositories
#
#  id              :uuid             not null, primary key
#  description     :text
#  name            :string           not null
#  path            :string           not null
#  read_only       :boolean          default(FALSE), not null
#  repository_type :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  server_id       :uuid             indexed
#  user_id         :uuid             not null, indexed
#
# Indexes
#
#  index_repositories_on_server_id  (server_id)
#  index_repositories_on_user_id    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (server_id => servers.id)
#  fk_rails_...  (user_id => users.id)
#
