# frozen_string_literal: true

RSpec.describe Servers::SSHService do
  subject(:service) { my_class.new(server) }

  let(:my_class) do
    Class.new(described_class) do
      def command = "echo ok"
      def category = "connectivity"
    end
  end

  let(:server) { create(:server) }

  describe "host key verification" do
    context "when verify_host_key config is enabled" do
      with_configuration "verify_host_key" => true

      context "when server fingerprint matches the host key" do
        before { stub_ssh(fingerprint: NetSSHHelpers::DEFAULT_FINGERPRINT) }

        it "connects successfully" do
          expect { service.call }.not_to raise_error
        end
      end

      context "when server fingerprint is blank" do
        let(:server) { create(:server, fingerprint: nil) }

        before { stub_ssh(fingerprint: NetSSHHelpers::DEFAULT_FINGERPRINT) }

        it "raises HostKeyMismatch" do
          expect { service.call }.to raise_error(Net::SSH::HostKeyMismatch)
        end
      end

      context "when server fingerprint does not match the host key" do
        before { stub_ssh(fingerprint: "SHA256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb") }

        it "raises HostKeyMismatch" do
          expect { service.call }.to raise_error(Net::SSH::HostKeyMismatch)
        end
      end
    end

    context "when verify_host_key config is disabled" do
      with_configuration "verify_host_key" => false

      let(:server) { create(:server, fingerprint: nil) }

      before { stub_ssh }

      it "connects without verifying the fingerprint" do
        expect { service.call }.not_to raise_error
      end
    end
  end

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
