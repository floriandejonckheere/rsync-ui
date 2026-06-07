# frozen_string_literal: true

RSpec.describe SchedulerJob do
  before { travel_to(Time.zone.local(2026, 4, 19, 2, 0, 30)) }

  describe "connectivity scheduling" do
    with_configuration "connectivity" => true, "connectivity.interval" => 15

    let!(:never_probed) { create(:server, :with_password) }
    let!(:recent) { create(:server, :with_password, probed_at: 2.minutes.ago) }
    let!(:stale) { create(:server, :with_password, probed_at: 30.minutes.ago) }

    it "enqueues Servers::ConnectionJob for never-probed and stale servers" do
      expect { described_class.perform_now }
        .to have_enqueued_job(Servers::ConnectionJob)
        .exactly(2).times

      expect(Servers::ConnectionJob)
        .to have_been_enqueued
        .with(never_probed)

      expect(Servers::ConnectionJob)
        .to have_been_enqueued
        .with(stale)

      expect(Servers::ConnectionJob)
        .not_to have_been_enqueued
        .with(recent)
    end

    context "when connectivity is disabled" do
      with_configuration "connectivity" => false

      it "does not enqueue any connectivity jobs" do
        expect { described_class.perform_now }
          .not_to have_enqueued_job(Servers::ConnectionJob)
      end
    end
  end

  describe "resource usage scheduling" do
    with_configuration "resource_usage" => true, "resource_usage.interval" => 15

    let!(:never_probed) { create(:server, :with_password) }
    let!(:recent) { create(:server, :with_password).tap { |s| create(:resource_usage, server: s, probed_at: 2.minutes.ago) } }
    let!(:stale) { create(:server, :with_password).tap { |s| create(:resource_usage, server: s, probed_at: 30.minutes.ago) } }

    it "enqueues Servers::ResourceUsageJob for never-probed and stale servers" do
      expect { described_class.perform_now }
        .to have_enqueued_job(Servers::ResourceUsageJob)
        .exactly(2).times

      expect(Servers::ResourceUsageJob)
        .to have_been_enqueued
        .with(never_probed)

      expect(Servers::ResourceUsageJob)
        .to have_been_enqueued
        .with(stale)

      expect(Servers::ResourceUsageJob)
        .not_to have_been_enqueued
        .with(recent)
    end

    context "when resource_usage is disabled" do
      with_configuration "resource_usage" => false

      it "does not enqueue any resource usage jobs" do
        expect { described_class.perform_now }
          .not_to have_enqueued_job(Servers::ResourceUsageJob)
      end
    end
  end
end
