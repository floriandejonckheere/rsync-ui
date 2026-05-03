# frozen_string_literal: true

RSpec.describe Notifications::RenderService do
  let(:job_run) do
    create(:job_run,
           status: "running",
           trigger: "manual",
           started_at: Time.zone.parse("2026-05-01 10:00:00"),)
  end

  describe "#call" do
    context "with start event" do
      subject(:result) { described_class.new(job_run, "start").call }

      it "returns title, body, and notification_type" do
        expect(result[:title]).to eq("Job started: #{job_run.job.name}")
        expect(result[:body]).to include(job_run.job.name)
        expect(result[:body]).to include(job_run.sequence.to_s)
        expect(result[:notification_type]).to eq("info")
      end
    end

    context "with success event" do
      subject(:result) { described_class.new(job_run, "success").call }

      before do
        job_run.update!(status: "completed", completed_at: Time.zone.parse("2026-05-01 10:05:00"))
      end

      it "includes completed_at and duration" do
        expect(result[:body]).to include("Completed at")
        expect(result[:body]).to include("Duration")
        expect(result[:notification_type]).to eq("success")
      end
    end

    context "with failure event" do
      subject(:result) { described_class.new(job_run, "failure").call }

      before do
        job_run.update!(
          status: "errored",
          completed_at: Time.zone.parse("2026-05-01 10:02:00"),
          error_class: "Errno::ENOENT",
          error_messages: "No such file or directory",
        )
      end

      it "includes error fields and notification_type failure" do
        expect(result[:body]).to include("Errno::ENOENT")
        expect(result[:body]).to include("No such file or directory")
        expect(result[:notification_type]).to eq("failure")
      end
    end
  end
end
