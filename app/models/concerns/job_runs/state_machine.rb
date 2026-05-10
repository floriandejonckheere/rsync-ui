# frozen_string_literal: true

module JobRuns
  module StateMachine
    extend ActiveSupport::Concern

    included do
      scope :pending,   -> { with_status(:pending) }
      scope :running,   -> { with_status(:running) }
      scope :completed, -> { with_status(:completed) }
      scope :failed,    -> { with_status(:failed) }
      scope :canceled,  -> { with_status(:canceled) }
      scope :errored,   -> { with_status(:errored) }

      state_machine :status, initial: :pending do
        ##
        # States
        #
        state :pending
        state :running
        state :completed
        state :failed
        state :canceled
        state :errored

        ##
        # Events
        #
        event :start do
          transition pending: :running
        end

        # Named :tick instead of :progress to avoid overriding the progress column reader
        event :tick do
          transition running: :running
        end

        event :complete do
          transition running: :completed
        end

        # Named :mark_failed instead of :fail to avoid overriding Kernel#fail (alias for raise)
        event :mark_failed do
          transition running: :failed
        end

        event :cancel do
          transition [:pending, :running] => :canceled
        end

        event :error do
          transition any => :errored
        end

        ##
        # Callbacks
        #
        before_transition to: :running do |job_run|
          job_run.started_at = Time.zone.now
        end

        before_transition to: [:completed, :failed, :canceled, :errored] do |job_run|
          job_run.completed_at = Time.zone.now
        end

        before_transition to: :canceled do |job_run|
          at = Time.zone.now

          job_run.cancel_requested_at ||= at
          job_run.canceled_at ||= at
        end

        before_transition on: :tick do |job_run, transition|
          kwargs = transition.args.first || {}

          job_run.bytes_copied = kwargs[:bytes_copied]
          job_run.progress = kwargs[:progress]
        end

        before_transition on: :error do |job_run, transition|
          kwargs = transition.args.first || {}

          job_run.error_class = kwargs[:error_class] if kwargs.key?(:error_class)
          job_run.error_messages = kwargs[:error_messages] if kwargs.key?(:error_messages)
        end

        after_transition on: :start do |job_run|
          next unless Configuration.get("streaming")

          JobRuns::BroadcastService.broadcast_started(job_run)
        end

        after_transition on: :tick do |job_run|
          next unless Configuration.get("streaming")

          JobRuns::BroadcastService.broadcast_progress(job_run)
        end

        after_transition on: [:complete, :mark_failed, :cancel, :error] do |job_run, transition|
          next unless Configuration.get("streaming")

          JobRuns::BroadcastService.broadcast_complete(job_run, from: transition.from)
        end
      end
    end
  end
end
