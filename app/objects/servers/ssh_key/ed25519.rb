# frozen_string_literal: true

module Servers
  class SSHKey
    class ED25519 < SSHKey
      def private_key
        pkey.private_to_pem
      end

      def public_key
        pkey.public_to_pem
      end

      def ssh_type
        "ssh-ed25519"
      end

      def openssh_public_key
        # DER SubjectPublicKeyInfo for ED25519 ends with the 32-byte raw public key
        raw_key = pkey.public_to_der[-32..]

        Base64.strict_encode64(
          [ssh_type.bytesize].pack("N") + ssh_type + [raw_key.bytesize].pack("N") + raw_key,
        )
      end

      private

      def pkey
        @pkey ||= OpenSSL::PKey.generate_key("ED25519")
      end
    end
  end
end
