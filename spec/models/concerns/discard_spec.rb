# frozen_string_literal: true

RSpec.describe Discard do
  with_model :DiscardTestRecord do
    table do |t|
      t.datetime :discarded_at

      t.timestamps
    end

    model do
      include Discard # rubocop:disable RSpec/DescribedClass
    end
  end

  it "defaults to discarded_at" do
    expect(DiscardTestRecord.discard_column_name).to eq(:discarded_at)
  end

  it "supports kept/discarded scopes and state transitions" do
    record = DiscardTestRecord.create!

    expect(record).to be_kept
    expect(DiscardTestRecord.kept).to include(record)
    expect(DiscardTestRecord.discarded).not_to include(record)

    record.discard!
    expect(record.reload).to be_discarded
    expect(DiscardTestRecord.kept).not_to include(record)
    expect(DiscardTestRecord.discarded).to include(record)

    record.restore!
    expect(record.reload).to be_kept
    expect(DiscardTestRecord.kept).to include(record)
    expect(DiscardTestRecord.discarded).not_to include(record)
  end

  it "is idempotent" do
    record = DiscardTestRecord.create!

    time1 = Time.zone.parse("2026-02-08 12:00:00")
    time2 = Time.zone.parse("2026-02-08 13:00:00")

    record.discard!(time1)
    expect(record.reload.discarded_at).to eq(time1)

    expect { record.discard!(time2) }.not_to raise_error
    expect(record.reload.discarded_at).to eq(time1)

    record.restore!
    expect(record.reload.discarded_at).to be_nil

    expect { record.restore! }.not_to raise_error
    expect(record.reload.discarded_at).to be_nil
  end

  describe "custom column" do
    with_model :ArchivedDiscardTestRecord do
      table do |t|
        t.datetime :archived_at
        t.timestamps
      end

      model do
        include Discard # rubocop:disable RSpec/DescribedClass

        discard_column :archived_at
      end
    end

    it "supports overriding the discard column" do
      expect(ArchivedDiscardTestRecord.discard_column_name).to eq(:archived_at)

      record = ArchivedDiscardTestRecord.create!
      expect(record).to be_kept

      record.discard!
      expect(record.reload.archived_at).to be_present
      expect(record).to be_discarded
    end
  end
end
