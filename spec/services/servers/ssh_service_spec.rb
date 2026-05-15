# frozen_string_literal: true

RSpec.describe Servers::SSHService do
  subject(:service) { my_class.new(server) }

  let(:my_class) do
    Class.new(described_class) do
      def command = "echo ok"
    end
  end

  let(:server) { create(:server) }

  describe "audit creation" do
    before { stub_ssh(output: "ok\n") }

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
