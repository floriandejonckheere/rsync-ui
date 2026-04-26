# frozen_string_literal: true

RSpec.describe ImportService do
  subject(:service) { import_service_class.new(path: tmp_path) }

  let(:import_service_class) do
    Class.new(described_class) do
      def imports
        @imports ||= []
      end

      private

      def import(row)
        imports << {
          id: row["id"].to_i,
          field_one: row["field_one"],
          field_two: row["field_two"],
          field_three: row["field_three"],
        }
      end

      def self.name
        "ImportService"
      end
    end
  end

  let(:tmp_path) { Pathname.new(Dir.mktmpdir) }

  after { FileUtils.remove_entry(tmp_path) }

  describe "#call" do
    context "when the CSV file exists" do
      before do
        tmp_path.join("imports.csv").write(<<~CSV)
          id,field_one,field_two,field_three
          1,Field one point one,field one point two,Field one point three
          2,Field two point one,field two point two,Field two point three
        CSV
      end

      it "imports data from the CSV" do
        expect { service.call }
          .to change { service.imports.size }
          .by(2)

        one, two = service.imports

        expect(one[:id]).to eq 1
        expect(one[:field_one]).to eq "Field one point one"
        expect(one[:field_two]).to eq "field one point two"

        expect(two[:id]).to eq 2
        expect(two[:field_one]).to eq "Field two point one"
        expect(two[:field_two]).to eq "field two point two"
      end
    end

    context "when the CSV file does not exist" do
      it "raises an error" do
        expect { service.call }
          .to raise_error ArgumentError
      end
    end
  end
end
