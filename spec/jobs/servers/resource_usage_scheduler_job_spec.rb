# frozen_string_literal: true

RSpec.describe Servers::ResourceUsageSchedulerJob do
  let!(:never_probed) { create(:server, :with_password) }

  let!(:recent) do
    create(:server, :with_password).tap { |s| create(:resource_usage, server: s, probed_at: 2.minutes.ago) }
  end
  let!(:stale) do
    create(:server, :with_password).tap { |s| create(:resource_usage, server: s, probed_at: 30.minutes.ago) }
  end

  before do
    Configuration.set("resource_usage", true)
    Configuration.set("resource_usage.interval", 15)
  end

  it "enqueues a ServerProbeJob only for never-probed and stale servers" do
    expect { described_class.perform_now }
      .to have_enqueued_job(Servers::ResourceUsageJob)
      .exactly(2).times

    expect(Servers::ResourceUsageJob).to have_been_enqueued.with(never_probed)
    expect(Servers::ResourceUsageJob).to have_been_enqueued.with(stale)
    expect(Servers::ResourceUsageJob).not_to have_been_enqueued.with(recent)
  end

  context "when resource_usage is disabled" do
    before { Configuration.set("resource_usage", false) }

    it "does not enqueue any jobs" do
      expect { described_class.perform_now }
        .not_to have_enqueued_job(Servers::ResourceUsageJob)
    end
  end
end
