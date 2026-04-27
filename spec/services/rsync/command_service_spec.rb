# frozen_string_literal: true

RSpec.describe Rsync::CommandService do
  subject(:command) { described_class.call(job:) }

  let(:source) { build(:repository, :local, path: "/data/source") }
  let(:destination) { build(:repository, :local, path: "/data/destination") }
  let(:job) { build(:job, source_repository: source, destination_repository: destination) }

  it "ends with source and destination paths" do
    expect(command).to end_with("/data/source /data/destination")
  end

  describe "boolean flags" do
    it "includes --recursive when opt_recursive is true" do
      job.opt_recursive = true
      expect(command).to include("--recursive")
    end

    it "omits --recursive when opt_recursive is false" do
      job.opt_recursive = false
      expect(command).not_to include("--recursive")
    end

    it "includes --archive when opt_archive is true" do
      job.opt_archive = true
      expect(command).to include("--archive")
    end

    it "includes --verbose when opt_verbose is true" do
      job.opt_verbose = true
      expect(command).to include("--verbose")
    end
  end

  describe "remote repositories" do
    let(:server) { build(:server, username: "deploy", host: "example.com", port: 22) }
    let(:source) { build(:repository, :remote, server:, path: "/data/source") }

    it "uses user@host:path format for remote source" do
      expect(command).to include("deploy@example.com:/data/source")
    end

    context "with a non-standard SSH port" do
      let(:server) { build(:server, username: "deploy", host: "example.com", port: 2222) }

      it "includes the SSH port flag" do
        expect(command).to include('-e "ssh -p 2222"')
      end
    end

    context "with the standard SSH port" do
      it "omits the SSH port flag" do
        expect(command).not_to include("-e")
      end
    end
  end

  describe "opt_superuser and opt_rsync_path" do
    it "defaults to rsync" do
      expect(command).to start_with("rsync ")
    end

    context "when opt_superuser is enabled" do
      before { job.opt_superuser = true }

      it "defaults to sudo rsync" do
        expect(command).to start_with("sudo rsync ")
      end

      context "when opt_rsync_path is set" do
        before { job.opt_rsync_path = "/usr/local/bin/rsync" }

        it "uses the custom path" do
          expect(command).to start_with("sudo /usr/local/bin/rsync ")
        end
      end
    end
  end

  describe "opt_arguments" do
    it "includes the mandatory arguments" do
      expect(command).to include("--info=progress2")
      expect(command).to include("--no-inc-recursive")
    end

    context "when set" do
      before { job.opt_arguments = "--bwlimit=1000" }

      it "appends the custom arguments" do
        expect(command).to include("--bwlimit=1000")
      end
    end

    context "when blank" do
      before { job.opt_arguments = nil }

      it "adds nothing extra" do
        expect(command).to end_with("/data/source /data/destination")
      end
    end
  end

  describe "opt_include" do
    context "when patterns are present" do
      before { job.opt_include = ["*.log", "docs/"] }

      it "adds a --include flag for each pattern" do
        expect(command).to include("--include=*.log")
        expect(command).to include("--include=docs/")
      end

      it "places include flags before the source path" do
        expect(command.index("--include=*.log")).to be < command.index("/data/source")
      end
    end

    context "when empty" do
      before { job.opt_include = [] }

      it "adds no --include flags" do
        expect(command).not_to include("--include=")
      end
    end
  end

  describe "opt_exclude" do
    context "when patterns are present" do
      before { job.opt_exclude = ["*.tmp", ".cache/"] }

      it "adds a --exclude flag for each pattern" do
        expect(command).to include("--exclude=*.tmp")
        expect(command).to include("--exclude=.cache/")
      end
    end

    context "when empty" do
      before { job.opt_exclude = [] }

      it "adds no --exclude flags" do
        expect(command).not_to include("--exclude=")
      end
    end
  end

  describe "include/exclude ordering" do
    before do
      job.opt_include = ["*.log"]
      job.opt_exclude = ["*.tmp"]
    end

    it "places all --include flags before all --exclude flags" do
      expect(command.index("--include=*.log")).to be < command.index("--exclude=*.tmp")
    end
  end

  describe "missing repositories" do
    let(:job) { build(:job, source_repository: nil, destination_repository: nil) }

    it "uses placeholder for source" do
      expect(command).to include("<source>")
    end

    it "uses placeholder for destination" do
      expect(command).to include("<destination>")
    end
  end
end
