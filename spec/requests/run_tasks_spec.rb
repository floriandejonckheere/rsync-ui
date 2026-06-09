# frozen_string_literal: true

RSpec.describe "Run tasks" do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin, scope: :user }

  describe "sync_ssh_config" do
    let(:task) { create(:task, class_name: "Servers::SyncSSHConfigTask") }

    it "calls Servers::SSHConfigService" do
      allow(Servers::SSHConfigService)
        .to receive :call

      run(task)

      expect(Servers::SSHConfigService)
        .to have_received :call
    end
  end

  describe "execute_jobs" do
    let(:task) { create(:task, class_name: "Jobs::ExecuteTask") }

    it "calls Jobs::ScheduleJobsService" do
      allow(Jobs::ScheduleJobsService)
        .to receive :call

      run(task)

      expect(Jobs::ScheduleJobsService)
        .to have_received :call
    end
  end

  describe "terminate_stuck_job_runs" do
    let(:task) { create(:task, class_name: "JobRuns::TerminateStuckTask") }

    it "calls JobRuns::TerminateStuckService" do
      allow(JobRuns::TerminateStuckService)
        .to receive :call

      run(task)

      expect(JobRuns::TerminateStuckService)
        .to have_received :call
    end
  end

  describe "check_connectivity" do
    let(:task) { create(:task, class_name: "Servers::CheckConnectivityTask") }
    let!(:server) { create(:server, :with_password) }

    it "calls Servers::ConnectionService for each server" do
      allow(Servers::ConnectionService)
        .to receive :call

      run(task)

      expect(Servers::ConnectionService)
        .to have_received(:call).with(server)
    end
  end

  describe "measure_resource_usage" do
    let(:task) { create(:task, class_name: "Servers::MeasureResourceUsageTask") }
    let!(:server) { create(:server, :with_password) }

    it "calls Servers::ResourceUsageService for each server" do
      allow(Servers::ResourceUsageService)
        .to receive :call

      run(task)

      expect(Servers::ResourceUsageService)
        .to have_received(:call).with(server)
    end
  end

  def run(task)
    post run_task_path(task), headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end
end
