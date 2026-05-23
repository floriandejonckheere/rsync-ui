# frozen_string_literal: true

RSpec.describe Tasks::ImportService do
  subject(:service) { described_class.new(path:) }

  let(:path) { Rails.root.join("spec/support/fixtures/tasks") }

  describe "#call" do
    it "creates tasks from CSV" do
      expect { service.call }
        .to change(Task, :count)
        .by(1)
    end

    it "sets the task attributes from CSV" do
      service.call

      task = Task.find_by!(name: "sync_ssh_config")

      expect(task.class_name).to eq "Tasks::SyncSSHConfigService"
      expect(task.configuration).to be_nil
    end

    it "is idempotent" do
      service.call

      expect { service.call }
        .not_to change(Task, :count)
    end
  end
end
