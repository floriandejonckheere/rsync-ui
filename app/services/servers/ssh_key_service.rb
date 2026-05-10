# frozen_string_literal: true

module Servers
  class SSHKeyService < ApplicationService
    def call
      private_key = generate_private_key
      public_key = OpenSSL::PKey.read(private_key.public_to_pem)

      { private_key:, public_key: }
    end

    private

    def generate_private_key
      case Configuration.get("connectivity.ssh_key.algorithm")
      when "rsa"
        OpenSSL::PKey::RSA.generate(Configuration.get("connectivity.ssh_key.length").to_i)
      when "ed25519"
        OpenSSL::PKey.generate_key("ED25519")
      when "ecdsa"
        OpenSSL::PKey::EC.generate("prime256v1")
      else
        raise "Unsupported SSH key algorithm"
      end
    end
  end
end
