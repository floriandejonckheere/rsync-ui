# frozen_string_literal: true

RSpec.describe Configuration do
  subject(:configuration) { build(:configuration) }

  describe "validations" do
    it { is_expected.to validate_presence_of :key }
    it { is_expected.to validate_uniqueness_of(:key).case_insensitive }
    it { is_expected.to validate_inclusion_of(:key).in_array described_class.configurations.keys }

    it { is_expected.to validate_presence_of(:value).allow_blank }
  end

  describe ".dependencies" do
    it "returns direct dependencies" do
      expect(described_class.dependencies("test.dependent")).to contain_exactly "test.feature"
    end

    it "does not return transitive dependencies" do
      expect(described_class.dependencies("test.transitive_dependent")).to contain_exactly "test.dependent"
    end
  end

  describe ".all_dependencies" do
    it "returns direct dependencies" do
      expect(described_class.all_dependencies("test.dependent")).to contain_exactly "test.feature"
    end

    it "returns transitive dependencies" do
      expect(described_class.all_dependencies("test.transitive_dependent")).to contain_exactly "test.feature", "test.dependent"
    end
  end

  describe "#dependents" do
    it "returns direct dependents" do
      expect(described_class.dependents("test.dependent")).to contain_exactly "test.transitive_dependent"
    end

    it "does not return transitive dependents" do
      expect(described_class.dependents("test.feature")).to contain_exactly "test.dependent"
    end
  end

  describe "#all_dependents" do
    it "returns direct dependents" do
      expect(described_class.all_dependents("test.dependent")).to contain_exactly "test.transitive_dependent"
    end

    it "returns transitive dependents" do
      expect(described_class.all_dependents("test.feature")).to contain_exactly "test.dependent", "test.transitive_dependent"
    end
  end

  describe ".dependencies_satisfied?" do
    context "when there are no dependencies" do
      it "returns true" do
        expect(described_class).to be_dependencies_satisfied "test.key"
      end
    end

    context "when dependencies are satisfied" do
      with_configuration "test.feature" => true

      it "returns true for direct dependencies" do
        expect(described_class).to be_dependencies_satisfied "test.dependent"
      end
    end

    context "when direct dependencies are not satisfied" do
      with_configuration "test.feature" => false

      it "returns false" do
        expect(described_class).not_to be_dependencies_satisfied "test.dependent"
      end
    end

    context "when top-level transitive dependencies are not satisfied" do
      with_configuration "test.feature" => false, "test.dependent" => "my_value"

      it "returns true" do
        expect(described_class).to be_dependencies_satisfied "test.transitive_dependent"
      end
    end

    context "when intermediary transitive dependencies are not satisfied" do
      with_configuration "test.feature" => false, "test.dependent" => nil

      it "returns false" do
        expect(described_class).not_to be_dependencies_satisfied "test.transitive_dependent"
      end
    end
  end

  describe ".all_dependencies_satisfied?" do
    context "when there are no dependencies" do
      it "returns true" do
        expect(described_class).to be_all_dependencies_satisfied "test.key"
      end
    end

    context "when dependencies are satisfied" do
      with_configuration "test.feature" => true

      it "returns true for direct dependencies" do
        expect(described_class).to be_all_dependencies_satisfied "test.dependent"
      end
    end

    context "when direct dependencies are not satisfied" do
      with_configuration "test.feature" => false

      it "returns false" do
        expect(described_class).not_to be_all_dependencies_satisfied "test.dependent"
      end
    end

    context "when top-level transitive dependencies are not satisfied" do
      with_configuration "test.feature" => false, "test.dependent" => "my_value"

      it "returns false" do
        expect(described_class).not_to be_all_dependencies_satisfied "test.transitive_dependent"
      end
    end

    context "when intermediary transitive dependencies are not satisfied" do
      with_configuration "test.feature" => false, "test.dependent" => nil

      it "returns false" do
        expect(described_class).not_to be_all_dependencies_satisfied "test.transitive_dependent"
      end
    end
  end

  describe ".get" do
    it "returns existing configuration" do
      create(:configuration, key: "test.key", value: "my_value")

      result = described_class.get("test.key")

      expect(result).to eq "my_value"
    end

    it "creates and returns default configuration if not existing" do
      result = described_class.get("test.key")

      expect(result).to eq described_class.configurations["test.key"][:default]
    end

    context "when dependencies are satisfied" do
      with_configuration "test.feature" => true

      it "returns value" do
        create(:configuration, key: "test.dependent", value: "my_value")

        expect(described_class.get("test.dependent")).to eq "my_value"
      end
    end

    context "when direct dependencies are not satisfied" do
      with_configuration "test.feature" => false

      it "returns nil" do
        create(:configuration, key: "test.dependent", value: "my_value")

        expect(described_class.get("test.dependent")).to be_nil
      end
    end

    context "when top-level transitive dependencies are not satisfied" do
      with_configuration "test.feature" => false, "test.dependent" => "my_value"

      it "returns nil" do
        create(:configuration, key: "test.transitive_dependent", value: "my_value")

        expect(described_class.get("test.transitive_dependent")).to be_nil
      end
    end

    context "when intermediary transitive dependencies are not satisfied" do
      with_configuration "test.feature" => true, "test.dependent" => nil

      it "returns nil" do
        create(:configuration, key: "test.transitive_dependent", value: "my_value")

        expect(described_class.get("test.transitive_dependent")).to be_nil
      end
    end
  end

  describe ".set" do
    it "updates existing configuration" do
      create(:configuration, key: "test.key", value: "old-value")

      described_class.set("test.key", "new-value")

      result = described_class.get("test.key")

      expect(result).to eq "new-value"
    end

    it "creates missing configuration" do
      described_class.set("test.key", "my_value")

      result = described_class.get("test.key")

      expect(result).to eq "my_value"
    end
  end
end
