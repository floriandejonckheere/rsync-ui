# frozen_string_literal: true

class ExecutionResult
  attr_reader :success,
              :exit_status

  def initialize(success: nil, exit_status: nil)
    @success = success
    @exit_status = exit_status
  end
end
