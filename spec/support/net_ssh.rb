# frozen_string_literal: true

module NetSSHHelpers
  DEFAULT_FINGERPRINT = "SHA256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  DEFAULT_HOST_KEY_BLOB = "test-key-blob"
  DEFAULT_HOST_KEY = "ssh-ed25519 #{Base64.strict_encode64(DEFAULT_HOST_KEY_BLOB)}".freeze

  def stub_ssh(output: "", exit_code: 0, fingerprint: DEFAULT_FINGERPRINT)
    key = double("host_key", ssh_type: "ssh-ed25519", to_blob: DEFAULT_HOST_KEY_BLOB) # rubocop:disable RSpec/VerifiedDoubles

    ssh = instance_double(Net::SSH::Connection::Session)
    channel = instance_double(Net::SSH::Connection::Channel)

    allow(Net::SSH)
      .to receive(:start) do |_host, _user, opts = {}, &block|
        if (verifier = opts[:verify_host_key]) && verifier.respond_to?(:verify)
          verifier.verify({ fingerprint:, key: })
        end

        block.call(ssh)
      end

    allow(ssh)
      .to receive(:open_channel)
      .and_yield(channel)

    allow(ssh)
      .to receive(:loop)

    allow(channel)
      .to receive(:exec)
      .and_yield(channel, true)

    allow(channel)
      .to receive(:on_data)
      .and_yield(channel, output)

    allow(channel)
      .to receive(:on_extended_data)

    allow(channel)
      .to receive(:on_request) do |name, &block|
      next unless name == "exit-status"

      data = instance_double(Net::SSH::Buffer)

      allow(data)
        .to receive(:read_long)
        .and_return(exit_code)

      block.call(nil, data)
    end

    channel
  end
end

RSpec.configure do |config|
  config.include NetSSHHelpers
end
