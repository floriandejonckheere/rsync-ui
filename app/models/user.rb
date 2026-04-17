# frozen_string_literal: true

class User < ApplicationRecord
  ROLES = [
    "user",
    "admin",
  ].freeze

  devise :database_authenticatable,
         :registerable,
         :trackable,
         :validatable

  has_many :servers,
           dependent: :destroy

  validates :first_name,
            presence: true

  validates :last_name,
            presence: true

  validates :email,
            presence: true,
            uniqueness: true

  validates :role,
            presence: true,
            inclusion: { in: ROLES }

  enum :role, {
    user: "user",
    admin: "admin",
  }, validate: true

  before_validation :downcase_email

  def user?
    role == "user"
  end

  def admin?
    role == "admin"
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  private

  def downcase_email
    email&.downcase!
  end
end

# == Schema Information
#
# Table name: users
#
#  id                     :uuid             not null, primary key
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string
#  email                  :string           default(""), not null, uniquely indexed
#  encrypted_password     :string           default(""), not null
#  first_name             :string           default(""), not null
#  last_name              :string           default(""), not null
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string
#  reset_password_sent_at :datetime
#  reset_password_token   :string           uniquely indexed
#  role                   :string           default("user"), not null
#  sign_in_count          :integer          default(0), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
