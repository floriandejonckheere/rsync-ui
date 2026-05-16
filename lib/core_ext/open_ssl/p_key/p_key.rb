# frozen_string_literal: true

module CoreExt
  module OpenSSL
    module PKey
      # Ed25519 keys in PKCS8 format ("BEGIN PRIVATE KEY") have no dedicated
      # subclass — OpenSSL::PKey.read returns the base OpenSSL::PKey::PKey.
      # net-ssh monkey-patches SSH methods onto RSA/EC/DSA subclasses only, so
      # those methods are missing on base-class Ed25519 key instances.
      module PKey
        def public_key
          ::OpenSSL::PKey.read(public_to_der)
        end

        def ssh_type
          raise NotImplementedError, "ssh_type not supported for key OID: #{oid}" unless oid == "ED25519"

          "ssh-ed25519"
        end

        alias ssh_signature_type ssh_type

        def to_blob
          Net::SSH::Buffer.from(:mstring, +"ssh-ed25519", :string, raw_public_key).to_s
        end

        def ssh_do_sign(data, _sig_alg = nil)
          sign(nil, data)
        end

        def ssh_do_verify(sig, data, _options = {})
          verify(nil, sig, data)
        end
      end
    end
  end
end

OpenSSL::PKey::PKey.prepend CoreExt::OpenSSL::PKey::PKey
