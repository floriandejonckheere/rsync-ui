# frozen_string_literal: true

RSpec.describe JobPreset do
  subject(:preset) { described_class.find("borg") }

  describe ".all" do
    it "returns all presets" do
      expect(described_class.all.map(&:key)).to eq(described_class::PRESETS.keys)
    end

    it "only enables toggleable options" do
      expect(described_class.all.flat_map(&:options)).to all(be_in(Job::TOGGLEABLE_OPTIONS))
    end
  end

  describe ".find" do
    it "returns nil for an unknown preset" do
      expect(described_class.find("unknown")).to be_nil
    end
  end

  describe "#attributes" do
    it "enables the options of the preset" do
      expect(preset.attributes).to include(opt_archive: true, opt_delete: true, opt_delete_after: true, opt_numeric_ids: true, opt_hard_links: true)
    end

    it "resets the other options to their defaults" do
      expect(preset.attributes).to include(opt_compress: false, opt_ignore_existing: false, opt_progress2: true, opt_no_inc_recursive: true)
    end

    it "sets the custom rsync arguments" do
      expect(preset.attributes).to include(opt_arguments: "--whole-file --sparse")
    end

    it "sets every toggleable option" do
      expect(preset.attributes.keys).to include(*Job::TOGGLEABLE_OPTIONS)
    end

    context "when the preset is additive" do
      subject(:preset) { described_class.find("trial_run") }

      it "only enables the options of the preset" do
        expect(preset.attributes).to eq(opt_dry_run: true, opt_itemize_changes: true)
      end
    end
  end

  described_class::PRESETS.each_key do |key|
    context "with the #{key} preset" do
      subject(:preset) { described_class.find(key) }

      it "has a translated name and description" do
        expect(I18n.exists?(:name, scope: [:job_presets, key])).to be true
        expect(I18n.exists?(:description, scope: [:job_presets, key])).to be true
      end

      it "produces a valid job" do
        job = build(:job, **preset.attributes)

        expect(job).to be_valid, job.errors.full_messages.to_sentence
      end
    end
  end
end
