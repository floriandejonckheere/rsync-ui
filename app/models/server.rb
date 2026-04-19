# frozen_string_literal: true

class Server < ApplicationRecord
  encrypts :password,
           :ssh_key

  belongs_to :user

  has_one :resource_usage,
          dependent: :destroy

  validates :name,
            presence: true

  validates :host,
            presence: true

  validates :port,
            presence: true,
            numericality: { only_integer: true, greater_than: 0, less_than: 65_536 }

  validates :username,
            presence: true

  validate :exclusive_credentials

  validate :valid_ssh_key,
           if: -> { ssh_key.present? }

  before_validation :normalize_ssh_key,
                    if: -> { ssh_key.present? }

  private

  def normalize_ssh_key
    self.ssh_key = "#{ssh_key.strip.gsub("\r\n", "\n")}\n"
  end

  def exclusive_credentials
    return if password.present? ^ ssh_key.present?

    errors.add(:base, :exclusive_credentials)
  end

  def valid_ssh_key
    # Validate OpenSSH private key format
    output, = Open3.capture2e("ssh-keygen", "-l", "-f", "/dev/stdin", stdin_data: ssh_key)

    return errors.add(:ssh_key, :ssh_key_invalid) if output.include?("is not a public key file")

    # Validate private key does not have a passphrase
    output, status = Open3.capture2e("ssh-keygen", "-y", "-P", "", "-f", "/dev/stdin", stdin_data: ssh_key)

    return if status.success?

    if output.include?("incorrect passphrase") || output.include?("bad passphrase") || output.include?("error in libcrypto")
      errors.add(:ssh_key, :ssh_key_passphrase)
    else
      errors.add(:ssh_key, :ssh_key_invalid)
    end
  end
end

# == Schema Information
#
# Table name: servers
#
#  id          :uuid             not null, primary key
#  description :text
#  host        :string           not null
#  name        :string           not null
#  password    :text
#  path        :string           default("/"), not null
#  port        :integer          default(22), not null
#  ssh_key     :text
#  username    :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :uuid             not null, indexed
#
# Indexes
#
#  index_servers_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
