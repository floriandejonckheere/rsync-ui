# frozen_string_literal: true

RSpec.describe Duplicatable do
  with_model :Widget do
    table do |t|
      t.string :color
      t.references :gadget

      t.timestamps
    end

    model do
      belongs_to :gadget
    end
  end

  with_model :Gadget do
    table do |t|
      t.string :name

      t.timestamps
    end

    model do
      include Duplicatable # rubocop:disable RSpec/DescribedClass

      has_many :widgets,
               dependent: :destroy

      duplicates_associations :widgets
    end
  end

  describe ".duplicates_associations" do
    it "sets duplication_associations" do
      expect(Gadget.duplication_associations).to contain_exactly(:widgets)
    end
  end

  describe "inheritance" do
    it "does not share the duplication_associations array with subclasses" do
      subclass = Class.new(Gadget)

      subclass.duplication_associations << :extra

      expect(Gadget.duplication_associations).to contain_exactly(:widgets)
    end
  end

  describe "#dup" do
    it "copies declared associations" do
      gadget = Gadget.create!(name: "original")
      gadget.widgets.create!(color: "red")
      gadget.widgets.create!(color: "blue")

      copy = gadget.dup
      copy.save!

      expect(copy.widgets.map(&:color)).to contain_exactly("red", "blue")
    end

    it "creates new records, not references to the originals" do
      gadget = Gadget.create!(name: "original")
      gadget.widgets.create!(color: "red")

      copy = gadget.dup
      copy.save!

      expect(copy.widgets.ids).not_to include(*gadget.widgets.ids)
    end

    it "does not affect the original's associations" do
      gadget = Gadget.create!(name: "original")
      gadget.widgets.create!(color: "red")

      copy = gadget.dup
      copy.save!

      expect(gadget.widgets.reload.count).to eq(1)
    end
  end
end
