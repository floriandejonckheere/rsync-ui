# frozen_string_literal: true

RSpec.describe Notifications::TestService do
  let(:notification) { create(:notification, name: "My Slack", url: "json://example.com/hook") }

  describe "#call" do
    context "when apprise succeeds" do
      before do
        allow(Open3)
          .to receive(:capture3)
          .and_return(["ok", "", instance_double(Process::Status, success?: true)])
      end

      it "returns success" do
        result = described_class.new(notification).call

        expect(result[:success]).to be(true)
      end

      it "sends a synthetic title and body with stdin URL" do
        described_class.new(notification).call

        expect(Open3).to have_received(:capture3) do |*args, **opts|
          expect(args).to include("apprise")
          expect(args).to include("--input-format=markdown")
          expect(args).to include("--notification-type=info")
          expect(args).to include("--config=-")
          expect(opts[:stdin_data]).to eq("json://example.com/hook\n")
        end
      end
    end

    context "when apprise fails" do
      before do
        allow(Open3)
          .to receive(:capture3)
          .and_return(["", "denied", instance_double(Process::Status, success?: false)])
      end

      it "returns failure with stderr in message" do
        result = described_class.new(notification).call

        expect(result[:success]).to be(false)
        expect(result[:message]).to include("denied")
      end
    end
  end
end
