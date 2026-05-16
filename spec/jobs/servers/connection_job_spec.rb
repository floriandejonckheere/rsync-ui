# frozen_string_literal: true

RSpec.describe Servers::ConnectionJob do
  subject(:job) { described_class.new }

  let(:service) { instance_double(Servers::ConnectionService, call: true) }
  let(:server) { build(:server) }

  it "calls Servers::ConnectionService" do
    allow(Servers::ConnectionService)
      .to receive(:new)
      .with(server)
      .and_return service

    job.perform(server)

    expect(service)
      .to have_received(:call)
  end

  context "when the server was probed recently" do
    with_configuration "connectivity.interval" => 5

    let(:server) { build(:server, probed_at: 2.minutes.ago) }

    it "does not call Servers::ConnectionService" do
      allow(Servers::ConnectionService)
        .to receive(:new)
        .with(server)
        .and_return service

      job.perform(server)

      expect(service)
        .not_to have_received(:call)
    end
  end
end
