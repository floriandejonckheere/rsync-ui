# frozen_string_literal: true

RSpec.describe Rsync::CommandService do
  subject(:command) { described_class.call(job:) }

  let(:source) { build(:repository, :local, path: "/data/source") }
  let(:destination) { build(:repository, :local, path: "/data/destination") }
  let(:job) { build(:job, source_repository: source, destination_repository: destination) }

  it "starts with rsync" do
    expect(command).to start_with("rsync ")
  end

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

  describe "opt_superuser" do
    context "when enabled without a custom rsync path" do
      before { job.opt_superuser = true }

      it "adds --rsync-path with sudo rsync" do
        expect(command).to include('--rsync-path="sudo rsync"')
      end
    end

    context "when enabled with a custom rsync path" do
      before do
        job.opt_superuser = true
        job.opt_rsync_path = "/usr/local/bin/rsync"
      end

      it "adds --rsync-path with sudo and the custom path" do
        expect(command).to include('--rsync-path="sudo /usr/local/bin/rsync"')
      end
    end
  end

  describe "opt_rsync_path" do
    context "when set without superuser" do
      before { job.opt_rsync_path = "/usr/local/bin/rsync" }

      it "adds --rsync-path with the custom path" do
        expect(command).to include('--rsync-path="/usr/local/bin/rsync"')
      end
    end
  end

  describe "opt_arguments" do
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
