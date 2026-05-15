# frozen_string_literal: true

module Servers
  class SSHKey
    class RSA < SSHKey
      attr_reader :bits

      def initialize(bits)
        super()

        @bits = bits
      end

      def private_key
        pkey.to_pem
      end

      def public_key
        pkey.public_key.to_pem
      end

      delegate :ssh_type, to: :pkey

      def openssh_public_key
        Base64.strict_encode64(Net::SSH::Buffer.from(:key, pkey).to_s)
      end

      private

      def pkey
        @pkey ||= OpenSSL::PKey::RSA.generate(bits)
      end
    end
  end
end
