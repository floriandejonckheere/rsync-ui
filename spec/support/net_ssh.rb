# frozen_string_literal: true

module NetSSHHelpers
  def stub_ssh(output: "", exit_code: 0)
    ssh = instance_double(Net::SSH::Connection::Session)
    channel = instance_double(Net::SSH::Connection::Channel)

    allow(Net::SSH)
      .to receive(:start)
      .and_yield(ssh)

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
