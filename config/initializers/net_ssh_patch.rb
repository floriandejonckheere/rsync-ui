# frozen_string_literal: true

# OpenSSL has no OpenSSL::PKey::Ed25519 subclass — Ed25519 keys (PKCS8 format,
# "BEGIN PRIVATE KEY") are returned as OpenSSL::PKey::PKey base class by
# OpenSSL::PKey.read. net-ssh expects ssh_type, to_blob, ssh_do_sign, etc. on
# key objects, but those are only monkey-patched onto RSA/EC/DSA subclasses.
# This patch adds the missing SSH methods to PKey::PKey for Ed25519 keys.
module OpenSSL
  module PKey
    class PKey
      def public_key
        OpenSSL::PKey.read(public_to_der)
      end unless method_defined?(:public_key)

      def ssh_type
        raise NotImplementedError, "ssh_type not supported for key OID: #{oid}" unless oid == "ED25519"

        "ssh-ed25519"
      end unless method_defined?(:ssh_type)

      alias_method :ssh_signature_type, :ssh_type unless method_defined?(:ssh_signature_type)

      def to_blob
        Net::SSH::Buffer.from(:mstring, +"ssh-ed25519", :string, raw_public_key).to_s
      end unless method_defined?(:to_blob)

      def ssh_do_sign(data, _sig_alg = nil)
        sign(nil, data)
      end unless method_defined?(:ssh_do_sign)

      def ssh_do_verify(sig, data, _options = {})
        verify(nil, sig, data)
      end unless method_defined?(:ssh_do_verify)
    end
  end
end
