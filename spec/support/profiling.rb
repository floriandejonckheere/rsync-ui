# frozen_string_literal: true

require "ruby-prof"
require "ruby-prof-flamegraph"

# Profile RSpec examples by adding `profile: true` to the test.
#
# Example:
#   it "does something", profile: true do
#     # your test code
#   end
#
# This will generate a flamegraph SVG file in tmp/flamegraphs/ directory.
#
FLAMEGRAPHS_DIR = Rails.root.join("tmp/flamegraphs").freeze
FLAMEGRAPH_SCRIPT = Rails.root.join("flamegraph.pl").freeze

RSpec.configure do |config|
  config.around(:each, :profile) do |example|
    FileUtils.mkdir_p(FLAMEGRAPHS_DIR)

    # Create a safe filename from the example description
    description = example
      .full_description
      .gsub(/[^a-zA-Z0-9\s]/, "")
      .gsub(/\s+/, "_")
      .downcase
      .truncate(100, omission: "")

    filename = "#{Time.zone.now.strftime('%Y%m%d_%H%M%S')}_#{description}"
    collapsed_file = FLAMEGRAPHS_DIR.join("#{filename}.collapsed")
    svg_file = FLAMEGRAPHS_DIR.join("#{filename}.svg")

    # Profile the example
    result = RubyProf::Profile.profile do
      example.run
    end

    # Write collapsed stack format for flamegraph.pl
    File.open(collapsed_file, "w") do |file|
      printer = RubyProf::FlameGraphPrinter.new(result)
      printer.print(file)
    end

    # Generate SVG flamegraph using flamegraph.pl
    system("perl #{FLAMEGRAPH_SCRIPT} #{collapsed_file} > #{svg_file}")

    # Clean up the intermediate collapsed file
    # FileUtils.rm_f(collapsed_file)
  end
end
