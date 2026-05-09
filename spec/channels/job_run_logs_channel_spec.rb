# frozen_string_literal: true

RSpec.describe JobRunLogsChannel do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:job_run) { create(:job_run, :running, user:) }

  before { stub_connection current_user: user }

  describe "#subscribed" do
    context "when authorized" do
      it "confirms subscription and streams from the job run channel" do
        subscribe job_run_id: job_run.id

        expect(subscription).to be_confirmed
        expect(subscription.streams).to include("job_run_logs_#{job_run.id}")
      end
    end

    context "when job run is not found" do
      it "rejects the subscription" do
        subscribe job_run_id: "00000000-0000-0000-0000-000000000000"

        expect(subscription).to be_rejected
      end
    end

    context "when user is not authorized" do
      before { stub_connection current_user: other_user }

      it "rejects the subscription" do
        subscribe job_run_id: job_run.id

        expect(subscription).to be_rejected
      end
    end

    context "when streaming feature is disabled" do
      with_configuration "streaming" => false

      it "rejects the subscription" do
        subscribe job_run_id: job_run.id

        expect(subscription).to be_rejected
      end
    end
  end
end
