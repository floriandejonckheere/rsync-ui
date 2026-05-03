# frozen_string_literal: true

class Hook < ApplicationRecord
  belongs_to :job

  enum :hook_type, {
    pre: "pre",
    post: "post",
    success: "success",
    failure: "failure",
  }, validate: true

  validates :hook_type,
            presence: true

  validates :command,
            presence: true
end

# == Schema Information
#
# Table name: hooks
#
#  id         :uuid             not null, primary key
#  arguments  :string
#  command    :string           not null
#  enabled    :boolean          default(FALSE), not null
#  hook_type  :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  job_id     :uuid             not null, indexed
#
# Indexes
#
#  index_hooks_on_job_id  (job_id)
#
# Foreign Keys
#
#  fk_rails_...  (job_id => jobs.id)
#
