# frozen_string_literal: true

RSpec.describe JobRuns::CancelJob do
  let(:job_run) { create(:job_run, :running, pid: 99_999) }

  it "is queued on the workers queue" do
    expect(described_class.new.queue_name).to eq("workers")
  end

  it "sends SIGTERM to the negative pid (process group)" do
    allow(Process)
      .to receive(:kill)

    described_class.perform_now(job_run)

    expect(Process)
      .to have_received(:kill)
      .with("TERM", -99_999)
  end

  it "is a no-op when pid is nil" do
    job_run.update!(pid: nil)

    allow(Process)
      .to receive(:kill)

    described_class.perform_now(job_run)

    expect(Process)
      .not_to have_received(:kill)
  end

  it "is a no-op when the process is already gone" do
    allow(Process)
      .to receive(:kill)
      .with("TERM", -99_999)
      .and_raise Errno::ESRCH

    expect { described_class.perform_now(job_run) }
      .not_to raise_error
  end

  it "is a no-op when EPERM is raised" do
    allow(Process)
      .to receive(:kill)
      .with("TERM", -99_999)
      .and_raise Errno::EPERM

    expect { described_class.perform_now(job_run) }
      .not_to raise_error
  end

  it "is a no-op when the job_run is no longer running or canceling" do
    job_run.update!(status: "completed", completed_at: Time.zone.now)

    allow(Process)
      .to receive(:kill)

    described_class.perform_now(job_run)

    expect(Process)
      .not_to have_received(:kill)
  end

  it "signals when the job_run is in canceling state" do
    job_run.update!(status: "canceling", cancel_requested_at: Time.zone.now)

    allow(Process)
      .to receive(:kill)

    described_class.perform_now(job_run)

    expect(Process)
      .to have_received(:kill)
      .with("TERM", -99_999)
  end
end
