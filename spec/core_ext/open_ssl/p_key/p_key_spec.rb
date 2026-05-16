# frozen_string_literal: true

RSpec.describe OpenSSL::PKey::PKey do
  context "when the key is an RSA key" do
    subject { OpenSSL::PKey.read(key.to_pem) }

    let(:key) { OpenSSL::PKey::RSA.new(2048) }

    it { is_expected.to respond_to :public_key }
    it { is_expected.to respond_to :ssh_type }
    it { is_expected.to respond_to :ssh_signature_type }
    it { is_expected.to respond_to :ssh_do_verify }
    it { is_expected.to respond_to :ssh_do_sign }
  end

  context "when the key is an ECDSA key" do
    subject { OpenSSL::PKey.read(key.to_pem) }

    let(:key) { OpenSSL::PKey::EC.generate("prime256v1") }

    it { is_expected.to respond_to :public_key }
    it { is_expected.to respond_to :ssh_type }
    it { is_expected.to respond_to :ssh_signature_type }
    it { is_expected.to respond_to :ssh_do_verify }
    it { is_expected.to respond_to :ssh_do_sign }
  end

  context "when the key is an ED25519 key" do
    subject { OpenSSL::PKey.read(key.public_to_pem) }

    let(:key) { OpenSSL::PKey.generate_key("ED25519") }

    it { is_expected.to respond_to :public_key }
    it { is_expected.to respond_to :ssh_type }
    it { is_expected.to respond_to :ssh_signature_type }
    it { is_expected.to respond_to :ssh_do_verify }
    it { is_expected.to respond_to :ssh_do_sign }
  end
end
