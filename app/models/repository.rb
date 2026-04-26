# frozen_string_literal: true

class Repository < ApplicationRecord
  enum :repository_type, { local: "local", remote: "remote" }, validate: true

  belongs_to :user
  belongs_to :server,
             optional: true

  has_many :source_jobs,
           class_name: "Job",
           foreign_key: :source_repository_id,
           inverse_of: :source_repository,
           dependent: :restrict_with_exception

  has_many :destination_jobs,
           class_name: "Job",
           foreign_key: :destination_repository_id,
           inverse_of: :destination_repository,
           dependent: :restrict_with_exception

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
end

# == Schema Information
#
# Table name: repositories
#
#  id              :uuid             not null, primary key
#  description     :text             indexed
#  name            :string           not null, indexed, indexed
#  path            :string           not null, indexed
#  read_only       :boolean          default(FALSE), not null
#  repository_type :string           not null, indexed
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  server_id       :uuid             indexed
#  user_id         :uuid             not null, indexed
#
# Indexes
#
#  index_repositories_on_description_trgm  (description) USING gin
#  index_repositories_on_name              (name)
#  index_repositories_on_name_trgm         (name) USING gin
#  index_repositories_on_path              (path)
#  index_repositories_on_repository_type   (repository_type)
#  index_repositories_on_server_id         (server_id)
#  index_repositories_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (server_id => servers.id)
#  fk_rails_...  (user_id => users.id)
#
