# frozen_string_literal: true

RSpec.describe "Run tasks" do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin, scope: :user }

  describe "sync_ssh_config" do
    let(:task) { create(:task, name: "sync_ssh_config", class_name: "Tasks::SyncSSHConfigService") }

    it "calls Servers::SSHConfigService" do
      allow(Servers::SSHConfigService)
        .to receive :call

      run(task)

      expect(Servers::SSHConfigService)
        .to have_received :call
    end
  end

  describe "execute_jobs" do
    let(:task) { create(:task, name: "execute_jobs", class_name: "Tasks::ExecuteJobsService") }

    it "calls Jobs::ScheduleJobsService" do
      allow(Jobs::ScheduleJobsService)
        .to receive :call

      run(task)

      expect(Jobs::ScheduleJobsService)
        .to have_received :call
    end
  end

  describe "terminate_stuck_job_runs" do
    let(:task) { create(:task, name: "terminate_stuck_job_runs", class_name: "Tasks::TerminateStuckJobs") }

    it "calls Jobs::TerminateStuckService" do
      allow(Jobs::TerminateStuckService)
        .to receive :call

      run(task)

      expect(Jobs::TerminateStuckService)
        .to have_received :call
    end
  end

  describe "check_connectivity" do
    let(:task) { create(:task, name: "check_connectivity", class_name: "Tasks::CheckConnectivityService") }
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
    let(:task) { create(:task, name: "measure_resource_usage", class_name: "Tasks::MeasureResourceUsage") }
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
