# frozen_string_literal: true

class JobRunLogsChannel < ApplicationCable::Channel
  def subscribed
    job_run = JobRun.find_by(id: params[:job_run_id])

    return reject unless job_run
    return reject unless Configuration.get("streaming")
    return reject unless JobRunPolicy.new(job_run, user: current_user).logs?

    stream_from "job_run_logs_#{params[:job_run_id]}"
  end
end
