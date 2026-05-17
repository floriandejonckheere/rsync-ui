# frozen_string_literal: true

RSpec.describe Servers::SSHConfigService do
  subject(:service) { described_class.new(ssh_dir: tmpdir) }

  let(:tmpdir) { Pathname.new(Dir.mktmpdir) }

  after { FileUtils.rm_rf(tmpdir) }

  describe "#call" do
    context "with a key-auth server" do
      let!(:server) { create(:server, :with_ssh_key) }

      before { service.call }

      it "writes the private key to ~/.ssh/<slug>.pem" do
        key_file = tmpdir
          .join("#{server.slug}.pem")

        expect(key_file).to exist
        expect(key_file.read).to eq server.ssh_key
        expect(key_file.stat.mode & 0o777).to eq 0o600
      end

      it "writes a Host config file entry with IdentityFile" do
        config = tmpdir
          .join("config")
          .read

        expect(config).to include "Host #{server.slug}"
        expect(config).to include "HostName #{server.host}"
        expect(config).to include "Port #{server.port}"
        expect(config).to include "User #{server.username}"
        expect(config).to include "IdentityFile #{tmpdir.join("#{server.slug}.pem")}"
        expect(config).to include "IdentitiesOnly yes"
      end

      it "does not write a password file for key-auth servers" do
        expect(tmpdir.join("#{server.slug}_password")).not_to exist
      end
    end

    context "with a password-auth server" do
      let!(:server) { create(:server, :with_password) }

      before { service.call }

      it "writes the password to ~/.ssh/<slug>_password" do
        password_file = tmpdir
          .join("#{server.slug}_password")

        expect(password_file).to exist
        expect(password_file.read).to eq server.password
        expect(password_file.stat.mode & 0o777).to eq 0o600
      end

      it "writes a Host config file entry without IdentityFile" do
        config = tmpdir
          .join("config")
          .read

        expect(config).to include "Host #{server.slug}"
        expect(config).not_to include "IdentityFile"
        expect(config).not_to include "IdentitiesOnly"
      end

      it "does not write a key file for password-auth servers" do
        expect(tmpdir.join(server.slug)).not_to exist
      end
    end

    context "with a mixed fleet" do
      let!(:key_server) { create(:server, :with_ssh_key) }
      let!(:pass_server) { create(:server, :with_password) }

      before { service.call }

      it "includes config file entries for both servers" do
        config = tmpdir
          .join("config")
          .read

        expect(config).to include "Host #{key_server.slug}"
        expect(config).to include "Host #{pass_server.slug}"
      end
    end

    context "with a server that has a host key" do
      let!(:server) { create(:server, :with_password, :with_host_key) }

      before { service.call }

      it "writes a known_hosts file with the server's host key entry" do
        known_hosts = tmpdir.join("#{server.slug}_known_hosts").read

        expect(known_hosts).to eq "[#{server.host}]:#{server.port} #{server.host_key}\n"
      end

      it "sets correct permissions on the known_hosts file" do
        expect(tmpdir.join("#{server.slug}_known_hosts").stat.mode & 0o777).to eq 0o600
      end

      it "uses StrictHostKeyChecking yes in the SSH config" do
        config = tmpdir.join("config").read

        expect(config).to include "StrictHostKeyChecking yes"
        expect(config).not_to include "StrictHostKeyChecking no"
      end

      it "points UserKnownHostsFile to the per-server known_hosts file" do
        config = tmpdir.join("config").read

        expect(config).to include "UserKnownHostsFile #{tmpdir.join("#{server.slug}_known_hosts")}"
        expect(config).not_to include "UserKnownHostsFile /dev/null"
      end
    end

    context "with a server that has no host key" do
      let!(:server) { create(:server, :with_password, host_key: nil) }

      before { service.call }

      it "writes an empty known_hosts file" do
        known_hosts = tmpdir.join("#{server.slug}_known_hosts")

        expect(known_hosts).to exist
        expect(known_hosts.read).to be_blank
      end

      it "still uses StrictHostKeyChecking yes" do
        config = tmpdir.join("config").read

        expect(config).to include "StrictHostKeyChecking yes"
      end
    end

    context "with orphaned key files" do
      let!(:server) { create(:server, :with_ssh_key) }
      let(:orphan_slug) { "deleted-server" }

      before do
        # Write orphan private key file
        tmpdir
          .join("#{orphan_slug}.pem")
          .write("orphan key")

        # Write orphan password file
        tmpdir
          .join("#{orphan_slug}_password")
          .write("orphan pass")

        service.call
      end

      it "removes the orphaned key file" do
        expect(tmpdir.join("#{orphan_slug}.pem")).not_to exist
      end

      it "removes the orphaned password file" do
        expect(tmpdir.join("#{orphan_slug}_password")).not_to exist
      end

      it "keeps files for existing servers" do
        expect(tmpdir.join("#{server.slug}.pem")).to exist
      end
    end

    context "with orphaned known_hosts files" do
      let(:orphan_slug) { "deleted-server" }

      before do
        tmpdir.join("#{orphan_slug}_known_hosts").write("orphan entry")
        service.call
      end

      it "removes the orphaned known_hosts file" do
        expect(tmpdir.join("#{orphan_slug}_known_hosts")).not_to exist
      end
    end

    context "when called multiple times" do
      it "produces the same result each time" do
        create(:server, :with_ssh_key)

        service.call

        config_first = tmpdir
          .join("config")
          .read

        service.call

        config_second = tmpdir
          .join("config")
          .read

        expect(config_first).to eq config_second
      end
    end

    it "sets the correct permissions on the config file" do
      create(:server, :with_password)

      service.call

      expect(tmpdir.join("config").stat.mode & 0o777).to eq 0o600
    end

    it "includes a header comment" do
      create(:server)
      service.call

      expect(tmpdir.join("config").read).to start_with "# Automatically generated by rsync-ui"
    end
  end
end
