# frozen_string_literal: true

module Servers
  class SSHKey
    class ECDSA < SSHKey
      def private_key
        pkey.to_pem
      end

      def public_key
        pkey.public_to_pem
      end

      delegate :ssh_type, to: :pkey

      def openssh_public_key
        Base64.strict_encode64(Net::SSH::Buffer.from(:key, pkey).to_s)
      end

      private

      def pkey
        @pkey ||= OpenSSL::PKey::EC.generate("prime256v1")
      end
    end
  end
end
