# frozen_string_literal: true

RSpec.describe Servers::SSHService do
  subject(:service) { my_class.new(server) }

  let(:my_class) do
    Class.new(described_class) do
      def command = "echo ok"
    end
  end

  let(:server) { create(:server) }

  def stub_ssh(output: "ok\n", exit_code: 0)
    ssh = instance_double(Net::SSH::Connection::Session)
    channel = instance_double(Net::SSH::Connection::Channel)

    allow(Net::SSH).to receive(:start).and_yield(ssh)
    allow(ssh).to receive(:open_channel).and_yield(channel)
    allow(ssh).to receive(:loop)
    allow(channel).to receive(:exec).and_yield(channel, true)
    allow(channel).to receive(:on_data).and_yield(channel, output)
    allow(channel).to receive(:on_extended_data)
    allow(channel).to receive(:on_request) do |name, &block|
      if name == "exit-status"
        data = instance_double(Net::SSH::Buffer)
        allow(data).to receive(:read_long).and_return(exit_code)
        block.call(nil, data)
      end
    end
  end

  describe "audit creation" do
    before { stub_ssh }

    context "when audits feature is enabled" do
      it "creates an audit record" do
        expect { service.call }.to change(Audit, :count).by(1)
      end

      it "records the command, output, exit status, server, and timestamps" do
        service.call

        audit = Audit.last

        expect(audit.server).to eq(server)
        expect(audit.command).to eq("echo ok")
        expect(audit.output).to eq("ok\n")
        expect(audit.exit_status).to eq(0)
        expect(audit.started_at).to be_present
        expect(audit.completed_at).to be_present
      end
    end

    context "when audits feature is disabled" do
      with_configuration "audits" => false

      it "does not create an audit record" do
        expect { service.call }
          .not_to change(Audit, :count)
      end
    end
  end
end
