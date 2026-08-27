# frozen_string_literal: true

RSpec.describe Configuration do
  subject(:configuration) { build(:configuration) }

  describe "validations" do
    it { is_expected.to validate_presence_of :key }
    it { is_expected.to validate_uniqueness_of(:key).case_insensitive }
    it { is_expected.to validate_inclusion_of(:key).in_array described_class.configurations.keys }

    it { is_expected.to validate_presence_of(:value).allow_blank }
  end

  describe "callbacks" do
    context "when a service is configured" do
      it "enqueues the associated job after commit" do
        service = instance_double(ApplicationService, call: true)
        stub_const("TestConfigurationService", service)

        described_class.set("test.with_service", "new_value")

        expect(service)
          .to have_received(:call)
          .twice # once when creating, once when updating
      end
    end

    context "when no service is configured" do
      it "does not raise" do
        expect { described_class.set("test.key", "new_value") }.not_to raise_error
      end
    end
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

  describe "#display_value" do
    context "when allowed_values is not defined" do
      subject(:configuration) { build(:configuration, key: "test.key", value: "my_value") }

      it "returns the raw value" do
        expect(configuration.display_value).to eq "my_value"
      end
    end

    context "when value is blank" do
      subject(:configuration) { build(:configuration, key: "test.key", value: nil) }

      it "returns the default value" do
        expect(configuration.display_value).to eq described_class.configurations["test.key"][:default]
      end
    end

    context "when allowed_values is defined without a translation" do
      subject(:configuration) { build(:string_configuration, key: "test.string_allowed", value: "foo") }

      it "returns the raw value" do
        expect(configuration.display_value).to eq "foo"
      end
    end

    context "when allowed_values is defined with a translation" do
      subject(:configuration) { build(:string_configuration, key: "test.string_allowed", value: "bar") }

      it "returns the translated label" do
        expect(configuration.display_value).to eq "Bar"
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

  describe Configuration::String do
    describe "validations" do
      context "when allowed_values is defined" do
        subject(:configuration) { build(:string_configuration, key: "test.string_allowed", value:) }

        context "with a value in the allowed list" do
          let(:value) { "foo" }

          it { is_expected.to be_valid }
        end

        context "with another value in the allowed list" do
          let(:value) { "bar" }

          it { is_expected.to be_valid }
        end

        context "with a value not in the allowed list" do
          let(:value) { "baz" }

          it { is_expected.not_to be_valid }
        end
      end

      context "when allowed_values is not defined" do
        subject(:configuration) { build(:string_configuration, key: "test.key", value:) }

        context "with any value" do
          let(:value) { "anything" }

          it { is_expected.to be_valid }
        end
      end
    end
  end

  describe Configuration::Integer do
    describe "validations" do
      context "when minimum and maximum are defined" do
        subject(:configuration) { build(:integer_configuration, key: "test.integer", value:) }

        context "with a value below the minimum" do
          let(:value) { 0 }

          it { is_expected.not_to be_valid }
        end

        context "with a value at the minimum" do
          let(:value) { 1 }

          it { is_expected.to be_valid }
        end

        context "with a value within range" do
          let(:value) { 5 }

          it { is_expected.to be_valid }
        end

        context "with a value at the maximum" do
          let(:value) { 10 }

          it { is_expected.to be_valid }
        end

        context "with a value above the maximum" do
          let(:value) { 11 }

          it { is_expected.not_to be_valid }
        end
      end

      context "when no minimum or maximum are defined" do
        subject(:configuration) { build(:integer_configuration, key: "test.integer_unbounded", value:) }

        context "with any value" do
          let(:value) { -999 }

          it { is_expected.to be_valid }
        end
      end
    end
  end

  describe Configuration::Float do
    describe "validations" do
      context "when minimum and maximum are defined" do
        subject(:configuration) { build(:float_configuration, key: "test.float", value:) }

        context "with a value below the minimum" do
          let(:value) { 0.5 }

          it { is_expected.not_to be_valid }
        end

        context "with a value at the minimum" do
          let(:value) { 1.0 }

          it { is_expected.to be_valid }
        end

        context "with a value within range" do
          let(:value) { 5.0 }

          it { is_expected.to be_valid }
        end

        context "with a value at the maximum" do
          let(:value) { 10.0 }

          it { is_expected.to be_valid }
        end

        context "with a value above the maximum" do
          let(:value) { 10.5 }

          it { is_expected.not_to be_valid }
        end
      end

      context "when no minimum or maximum are defined" do
        subject(:configuration) { build(:float_configuration, key: "test.float_unbounded", value:) }

        context "with any value" do
          let(:value) { -999.9 }

          it { is_expected.to be_valid }
        end
      end
    end
  end
end
