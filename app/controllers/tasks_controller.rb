# frozen_string_literal: true

class TasksController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :authenticate_user!
  before_action :set_task, only: [:run]

  def run
    authorize! @task, to: :run?

    Tasks::ExecuteService.call(@task, user: current_user)

    render turbo_stream: turbo_stream.replace(
      dom_id(@task, :status),
      partial: "tasks/task_status",
      locals: { task: @task.reload },
    )
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end
end
