# frozen_string_literal: true

module Servers
  class SSHKey
    def private_key
      raise NotImplementedError
    end

    def public_key
      raise NotImplementedError
    end

    def openssh_public_key
      raise NotImplementedError
    end

    def ssh_type
      raise NotImplementedError
    end
  end
end
