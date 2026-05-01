# frozen_string_literal: true

RSpec.describe Notifications::SendService do
  let(:notification) { create(:notification, url: "json://example.com/hook") }
  let(:job_run) { create(:job_run) }
  let(:rendered_payload) { { title: "T", body: "B", notification_type: "info" } }
  let(:render_service) { instance_double(Notifications::RenderService, call: rendered_payload) }

  before do
    allow(Notifications::RenderService)
      .to receive(:new)
      .with(job_run, "start")
      .and_return render_service
  end

  describe "#call" do
    context "when apprise succeeds" do
      before do
        allow(Open3)
          .to receive(:capture3)
          .and_return(["ok", "", instance_double(Process::Status, success?: true)])
      end

      it "returns success result" do
        result = described_class.new(notification, job_run, "start").call

        expect(result[:success]).to be(true)
      end

      it "invokes apprise with rendered title and body" do
        described_class.new(notification, job_run, "start").call

        expect(Open3).to have_received(:capture3) do |*args|
          expect(args).to include("apprise")
          expect(args).to include("--input-format=markdown")
          expect(args).to include("--title=T")
          expect(args).to include("--body=B")
          expect(args).to include("--notification-type=info")
          expect(args).to include("json://example.com/hook")
        end
      end
    end

    context "when apprise fails" do
      before do
        allow(Open3)
          .to receive(:capture3)
          .and_return(["", "boom", instance_double(Process::Status, success?: false)])
      end

      it "returns failure result with output" do
        result = described_class.new(notification, job_run, "start").call

        expect(result[:success]).to be(false)
        expect(result[:output]).to include("boom")
      end
    end

    context "when apprise times out" do
      before do
        allow(Open3).to receive(:capture3).and_raise(Timeout::Error)
      end

      it "returns failure result without raising" do
        result = described_class.new(notification, job_run, "start").call

        expect(result[:success]).to be(false)
      end
    end
  end
end
