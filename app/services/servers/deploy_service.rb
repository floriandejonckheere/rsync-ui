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
          ssh_key: private_key.to_pem,
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
      "echo \"#{key_ssh_type} #{openssh_public_key} Rsync UI key\" >> ~/.ssh/authorized_keys"
    end

    def key_ssh_type
      return public_key.ssh_type if public_key.respond_to?(:ssh_type)

      # OpenSSL::PKey::PKey (e.g. ED25519) doesn't have ssh_type patched by net-ssh
      case public_key.oid
      when "ED25519" then "ssh-ed25519"
      else raise "Unsupported SSH key type: #{public_key.oid}"
      end
    end

    private

    def keys
      @keys ||= SSHKeyService.call
    end

    def private_key
      keys[:private_key]
    end

    def public_key
      keys[:public_key]
    end

    def openssh_public_key
      Base64.strict_encode64(public_key_blob)
    end

    def public_key_blob
      if public_key.respond_to?(:to_blob)
        Net::SSH::Buffer.from(:key, public_key).to_s
      else
        # OpenSSL::PKey::PKey (e.g. ED25519) doesn't have to_blob patched by net-ssh;
        # construct the SSH wire-format blob manually.
        # DER SubjectPublicKeyInfo for ED25519 ends with the 32-byte raw public key.
        type = key_ssh_type
        raw_key = public_key.public_to_der[-32..]
        [type.bytesize].pack("N") + type + [raw_key.bytesize].pack("N") + raw_key
      end
    end
  end
end
