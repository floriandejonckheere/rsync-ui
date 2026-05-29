# frozen_string_literal: true

RSpec.describe Tasks::ExecuteService do
  subject(:service) { described_class.new(task, user:) }

  let(:task) { create(:task, class_name: "Servers::SyncSSHConfigTask") }
  let(:user) { create(:user, :admin) }

  describe "#call" do
    context "when task executes successfully" do
      before { allow(Servers::SyncSSHConfigTask).to receive(:call) }

      it "calls the service and returns success" do
        task.update!(status: "failed", error_class: "StandardError", error_message: "old error")

        expect(service.call).to eq success: true

        task.reload
        expect(task.status).to eq "completed"
        expect(task.last_run_at).to be_present
        expect(task.last_run_by_id).to eq user.id
        expect(task.error_class).to be_nil
        expect(task.error_message).to be_nil
      end
    end

    context "when task raises an error" do
      before do
        allow(Servers::SyncSSHConfigTask)
          .to receive(:call)
          .and_raise StandardError, "SSH config failed"
      end

      it "calls the service and returns failure with message" do
        expect(service.call).to eq success: false, message: "StandardError: SSH config failed"

        task.reload
        expect(task.status).to eq "failed"
        expect(task.error_class).to eq "StandardError"
        expect(task.error_message).to eq "SSH config failed"
        expect(task.last_run_at).to be_present
        expect(task.last_run_by_id).to eq user.id
      end
    end
  end
end
