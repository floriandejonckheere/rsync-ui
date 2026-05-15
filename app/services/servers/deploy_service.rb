# frozen_string_literal: true

module Servers
  class DeployService < SSHService
    def call
      # Don't generate and deploy SSH key if one is already configured
      if server.ssh_key?
        server.update!(
          probed_at: Time.zone.now,
          last_seen_at: Time.zone.now,
          error_class: StandardError.name,
          error_message: "Server already has an SSH key",
        )

        return { success: false, message: "Server already has an SSH key" }
      end

      # Deploy public key to server
      super

      # Write private key to server
      server
        .reload
        .update!(
          password: nil,
          ssh_key: ssh_key.private_key,
          probed_at: Time.zone.now,
          last_seen_at: Time.zone.now,
          error_class: nil,
          error_message: nil,
        )

      { success: true }
    rescue StandardError => e
      server.reload.update!(
        probed_at: Time.zone.now,
        error_class: e.class.to_s,
        error_message: e.message,
      )

      { success: false, message: "#{e.class}: #{e.message}" }
    end

    protected

    def command
      "echo \"#{ssh_key.ssh_type} #{ssh_key.openssh_public_key} Rsync UI key\" >> ~/.ssh/authorized_keys"
    end

    private

    def ssh_key
      @ssh_key ||= case Configuration.get("connectivity.ssh_key.algorithm")
                   when "rsa" then SSHKey::RSA.new(Configuration.get("connectivity.ssh_key.length").to_i)
                   when "ed25519" then SSHKey::ED25519.new
                   when "ecdsa" then SSHKey::ECDSA.new
                   else raise "Unsupported SSH key algorithm"
                   end
    end
  end
end
