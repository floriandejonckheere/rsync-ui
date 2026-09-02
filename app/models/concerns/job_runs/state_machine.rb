# frozen_string_literal: true

module JobRuns
  module StateMachine # rubocop:disable Metrics/ModuleLength
    extend ActiveSupport::Concern

    included do
      scope :pending,   -> { with_status(:pending) }
      scope :running,   -> { with_status(:running) }
      scope :canceling, -> { with_status(:canceling) }
      scope :completed, -> { with_status(:completed) }
      scope :failed,    -> { with_status(:failed) }
      scope :canceled,  -> { with_status(:canceled) }
      scope :errored,   -> { with_status(:errored) }

      state_machine :status, initial: :pending do
        ##
        # States
        #
        state :pending    # Initial state
        state :running    # Currently executing
        state :canceling  # Cancel requested by user
        state :completed  # Completed successfully
        state :failed     # Competed with failure
        state :canceled   # Canceled by user
        state :errored    # Completed with error

        ##
        # Events
        #
        event :start do
          transition pending: :running
        end

        event :tick_progress do
          transition running: :running
        end

        event :tick_status do
          transition running: :running
        end

        event :complete do
          transition running: :completed
        end

        # Named :mark_failed instead of :fail to avoid overriding Kernel#fail (alias for raise)
        event :mark_failed do
          transition running: :failed
        end

        event :request_cancel do
          transition pending: :canceled
          transition running: :canceling
        end

        event :cancel do
          transition canceling: :canceled
        end

        event :error do
          transition [:pending, :running, :canceling] => :errored
        end

        ##
        # Callbacks
        #
        before_transition on: :start do |job_run|
          job_run.started_at = Time.zone.now
        end

        before_transition to: [:completed, :failed, :canceled, :errored] do |job_run|
          job_run.completed_at ||= Time.zone.now
        end

        before_transition on: :request_cancel do |job_run|
          job_run.cancel_requested_at ||= Time.zone.now
        end

        before_transition to: :canceled do |job_run|
          at = Time.zone.now

          job_run.cancel_requested_at ||= at
          job_run.canceled_at ||= at
        end

        before_transition on: :tick_progress do |job_run, transition|
          kwargs = transition.args.first || {}

          job_run.bytes_copied = kwargs[:bytes_copied]
          job_run.progress = kwargs[:progress]
          job_run.speed = kwargs[:speed]
          job_run.remaining_time = kwargs[:remaining_time]
          job_run.remaining_time_approximate = kwargs[:remaining_time_approximate] || false
          job_run.files_transferred = kwargs[:files_transferred]
          job_run.files_total = kwargs[:files_total]

          true
        end

        before_transition on: :error do |job_run, transition|
          kwargs = transition.args.first || {}

          job_run.error_class = kwargs[:error_class] if kwargs.key?(:error_class)
          job_run.error_message = kwargs[:error_message] if kwargs.key?(:error_message)
          job_run.error_stacktrace = kwargs[:error_stacktrace] if kwargs.key?(:error_stacktrace)
        end

        after_transition on: :start do |job_run, _transition|
          next unless Configuration.get("streaming")

          JobRuns::BroadcastService.broadcast_started(job_run)
        end

        after_transition on: :tick_progress do |job_run, _transition|
          next unless Configuration.get("streaming")

          JobRuns::BroadcastService.broadcast_progress(job_run)
        end

        after_transition on: :tick_status do |job_run, transition|
          next unless Configuration.get("streaming")

          kwargs = transition.args.first || {}
          JobRuns::BroadcastService.broadcast_status(job_run, kwargs[:type], kwargs[:content])
        end

        after_transition on: :request_cancel do |job_run, _transition|
          next unless Configuration.get("streaming")

          JobRuns::BroadcastService.broadcast_canceling(job_run)
        end

        after_transition to: [:completed, :failed, :canceled, :errored] do |job_run, _transition|
          JobRuns::OutputBuffer.attach(job_run)
        end

        after_transition to: [:completed, :failed, :canceled, :errored] do |job_run, transition|
          next unless Configuration.get("streaming")

          JobRuns::BroadcastService.broadcast_complete(job_run, from: transition.from)
        end

        after_transition to: [:completed, :failed, :canceled, :errored] do |job_run, _transition|
          next unless Configuration.get("disk_size")

          Repositories::DiskSizeJob.perform_later(job_run.job.destination_repository)
        end
      end

      ##
      # Predicates
      #
      def cancelable?
        pending? || running?
      end

      def deletable?
        completed? || failed? || canceled? || errored?
      end
    end
  end
end
