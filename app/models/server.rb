# frozen_string_literal: true

class Server < ApplicationRecord
  encrypts :password,
           :ssh_key

  belongs_to :user

  has_one :resource_usage,
          dependent: :destroy

  has_many :repositories,
           dependent: :destroy

  has_many :audits,
           dependent: :destroy

  enum :operating_system, {
    linux: "linux",
    macos: "macos",
    hetzner: "hetzner",
  }, validate: true

  validates :name,
            presence: true

  validates :slug,
            presence: true,
            uniqueness: { case_sensitive: false }

  validates :host,
            presence: true

  validates :port,
            presence: true,
            numericality: { only_integer: true, greater_than: 0, less_than: 65_536 }

  validates :username,
            presence: true

  validates :fingerprint,
            format: { with: %r(\ASHA256:[A-Za-z0-9+/=]{43}\z) },
            allow_blank: true

  validates :host_key,
            format: { with: %r(\A(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) [A-Za-z0-9+/=]+\z) },
            allow_blank: true

  validate :exclusive_credentials

  validate :valid_ssh_key,
           if: -> { ssh_key.present? }

  before_validation :generate_slug

  before_validation :normalize_ssh_key,
                    if: -> { ssh_key.present? }

  after_commit :sync_ssh_config

  def online?
    last_seen_at.present?
  end

  def offline?
    last_seen_at.nil?
  end

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

  def generate_slug
    return if slug.present?

    base = name.to_s.parameterize
    candidate = base
    n = 1

    candidate = "#{base}-#{n += 1}" while Server.where.not(id:).exists?(slug: candidate)

    self.slug = candidate
  end

  def sync_ssh_config
    Servers::SyncSSHConfigJob.perform_later
  end
end

# == Schema Information
#
# Table name: servers
#
#  id               :uuid             not null, primary key
#  description      :text             indexed
#  error_class      :string
#  error_message    :text
#  fingerprint      :string
#  host             :string           not null, indexed, indexed
#  host_key         :text
#  last_seen_at     :datetime
#  name             :string           not null, indexed, indexed
#  operating_system :string           default("linux")
#  password         :text
#  path             :string           default("/"), not null
#  port             :integer          default(22), not null
#  probed_at        :datetime
#  slug             :string           not null, uniquely indexed
#  ssh_key          :text
#  username         :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  user_id          :uuid             not null, indexed
#
# Indexes
#
#  index_servers_on_description_trgm  (description) USING gin
#  index_servers_on_host              (host)
#  index_servers_on_host_trgm         (host) USING gin
#  index_servers_on_name              (name)
#  index_servers_on_name_trgm         (name) USING gin
#  index_servers_on_slug              (slug) UNIQUE
#  index_servers_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
