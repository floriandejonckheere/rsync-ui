# frozen_string_literal: true

RSpec.describe ApplicationHelper do
  describe "#page_title" do
    it "returns the application name without a page title" do
      expect(helper.page_title).to eq "rsync ui"
    end

    it "prefixes the page title with the application name" do
      helper.content_for(:title) { "\n  Jobs\n" }

      expect(helper.page_title).to eq "rsync ui - Jobs"
    end

    it "does not double-escape the page title" do
      helper.content_for(:title, "Tom's & Jerry's")

      expect(helper.page_title).to eq "rsync ui - Tom's & Jerry's"
    end
  end
end
