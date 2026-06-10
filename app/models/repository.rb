# frozen_string_literal: true

class Repository < ApplicationRecord
  include Duplicatable

  belongs_to :user
  belongs_to :server,
             optional: true

  has_many :source_jobs,
           class_name: "Job",
           foreign_key: :source_repository_id,
           inverse_of: :source_repository,
           dependent: :destroy

  has_many :destination_jobs,
           class_name: "Job",
           foreign_key: :destination_repository_id,
           inverse_of: :destination_repository,
           dependent: :destroy

  enum :repository_type, {
    local: "local",
    remote: "remote",
  }, validate: true

  enum :disk_size_status, {
    ok: "ok",
    failed: "failed",
  }, prefix: :disk_size, validate: { allow_nil: true }

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
#  id                      :uuid             not null, primary key
#  description             :text             indexed
#  disk_size               :bigint
#  disk_size_error_class   :string
#  disk_size_error_message :text
#  disk_size_measured_at   :datetime         indexed
#  disk_size_status        :string
#  name                    :string           not null, indexed, indexed
#  path                    :string           not null, indexed
#  read_only               :boolean          default(FALSE), not null
#  repository_type         :string           not null, indexed
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  server_id               :uuid             indexed
#  user_id                 :uuid             not null, indexed
#
# Indexes
#
#  index_repositories_on_description_trgm       (description) USING gin
#  index_repositories_on_disk_size_measured_at  (disk_size_measured_at)
#  index_repositories_on_name                   (name)
#  index_repositories_on_name_trgm              (name) USING gin
#  index_repositories_on_path                   (path)
#  index_repositories_on_repository_type        (repository_type)
#  index_repositories_on_server_id              (server_id)
#  index_repositories_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (server_id => servers.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id)
#
