# frozen_string_literal: true

RSpec.describe Servers::SSHKeyService do
  subject(:service) { described_class.new }

  describe "#call" do
    subject(:result) { service.call }

    context "with RSA algorithm" do
      with_configuration "connectivity.ssh_key.algorithm" => "rsa",
                         "connectivity.ssh_key.length" => 2048

      let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }

      before do
        allow(OpenSSL::PKey::RSA)
          .to receive(:generate)
          .with(2048)
          .and_return(rsa_key)
      end

      it "generates an RSA key pair" do
        expect(result[:private_key]).to be_an OpenSSL::PKey::RSA
        expect(result[:public_key]).to be_an OpenSSL::PKey::RSA
      end

      it "returns the private and public key" do
        expect(result[:private_key]).to be rsa_key
        expect(result[:public_key].public_to_pem).to eq rsa_key.public_to_pem
      end
    end

    context "with ed25519 algorithm" do
      with_configuration "connectivity.ssh_key.algorithm" => "ed25519"

      let(:ed25519_key) { OpenSSL::PKey.generate_key("ED25519") }

      before do
        allow(OpenSSL::PKey)
          .to receive(:generate_key)
          .with("ED25519")
          .and_return(ed25519_key)
      end

      it "generates an ed25519 key pair" do
        expect(result[:private_key]).to be_an OpenSSL::PKey::PKey
        expect(result[:public_key]).to be_an OpenSSL::PKey::PKey
      end

      it "returns the private and public key" do
        expect(result[:private_key]).to be ed25519_key
        expect(result[:public_key].public_to_pem).to eq ed25519_key.public_to_pem
      end
    end

    context "with ECDSA algorithm" do
      with_configuration "connectivity.ssh_key.algorithm" => "ecdsa"

      let(:ec_key) { OpenSSL::PKey::EC.generate("prime256v1") }

      before do
        allow(OpenSSL::PKey::EC)
          .to receive(:generate)
          .with("prime256v1")
          .and_return(ec_key)
      end

      it "generates an ECDSA key pair" do
        expect(result[:private_key]).to be_an OpenSSL::PKey::EC
        expect(result[:public_key]).to be_an OpenSSL::PKey::EC
      end

      it "returns the private and public key" do
        expect(result[:private_key]).to be ec_key
        expect(result[:public_key].public_to_pem).to eq ec_key.public_to_pem
      end
    end
  end
end
