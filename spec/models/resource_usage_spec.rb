# frozen_string_literal: true

RSpec.describe ResourceUsage do
  subject(:resource_usage) { build(:resource_usage) }

  describe "associations" do
    it { is_expected.to belong_to(:server) }
  end

  describe "enums" do
    it "defines an enum for status" do
      expect(resource_usage)
        .to define_enum_for(:status)
        .with_values(ok: "ok", failed: "failed")
        .backed_by_column_of_type(:string)
    end
  end

  describe "instance methods" do
    before do
      Configuration.set("resource_usage.cpu_warning", 75)
      Configuration.set("resource_usage.cpu_critical", 90)
      Configuration.set("resource_usage.memory_warning", 80)
      Configuration.set("resource_usage.memory_critical", 95)
      Configuration.set("resource_usage.disk_warning", 80)
      Configuration.set("resource_usage.disk_critical", 95)
    end

    describe "#memory_percent" do
      it "returns percentage" do
        usage = build_stubbed(:resource_usage, memory_used: 50, memory_total: 200)

        expect(usage.memory_percent).to eq 25.0
      end

      it "returns nil when total is nil" do
        usage = build_stubbed(:resource_usage, memory_used: 10, memory_total: nil)

        expect(usage.memory_percent).to be_nil
      end

      it "returns nil when used is nil" do
        usage = build_stubbed(:resource_usage, memory_used: nil, memory_total: 100)

        expect(usage.memory_percent).to be_nil
      end
    end

    describe "#disk_percent" do
      it "returns percentage" do
        usage = build_stubbed(:resource_usage, disk_used: 50, disk_total: 200)

        expect(usage.disk_percent).to eq 25.0
      end

      it "returns nil when total is zero" do
        usage = build_stubbed(:resource_usage, disk_used: 10, disk_total: 0)

        expect(usage.disk_percent).to be_nil
      end
    end

    describe "#cpu_health" do
      it "returns :ok below warning threshold" do
        usage = build_stubbed(:resource_usage, cpu_usage: 50)

        expect(usage.cpu_health).to eq :ok
      end

      it "returns :warning at warning threshold" do
        usage = build_stubbed(:resource_usage, cpu_usage: 80)

        expect(usage.cpu_health).to eq :warning
      end

      it "returns :critical at critical threshold" do
        usage = build_stubbed(:resource_usage, cpu_usage: 95)

        expect(usage.cpu_health).to eq :critical
      end

      it "returns :unknown for nil value" do
        usage = build_stubbed(:resource_usage, cpu_usage: nil)

        expect(usage.cpu_health).to eq :unknown
      end
    end

    describe "#memory_health" do
      it "returns :warning at warning threshold" do
        usage = build_stubbed(:resource_usage, memory_used: 85, memory_total: 100)

        expect(usage.memory_health).to eq :warning
      end
    end

    describe "#disk_health" do
      it "returns :critical at critical threshold" do
        usage = build_stubbed(:resource_usage, disk_used: 99, disk_total: 100)

        expect(usage.disk_health).to eq :critical
      end
    end
  end
end
