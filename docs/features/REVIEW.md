# Architecture review

1. A failing post/success/failure hook overwrites the rsync result with errored.
   execute_optional_hook calls job_run.error! when a hook fails (execute_service.rb:168), and the
   error event uses any => :errored. So a rsync run that successfully completed (and already sent a
   "success" notification) ends up persisted as errored — losing the actual rsync outcome and
   creating an inconsistency with the notification that was already enqueued. Either:
- Record hook failures on a separate column (e.g. post_hook_status/post_hook_error), leaving
  status as the rsync outcome, or
- Restrict error transitions so post-rsync hook failures don't downgrade a terminal state.

2. Cancel-while-pending races against the worker and corrupts state. CancelService transitions
   pending → canceled without coordinating with ExecuteService. The worker checks job_run.pending?
   (line 18) without a lock; if cancel slips in between that check and start!, the start! raises
   InvalidTransition from canceled, falls through to the outer rescue StandardError, and
   job_run.error! flips it to errored. Fix by wrapping the pending→running check + transition in
   with_lock, or by guarding the outer rescue to skip canceled runs.

3. Cancel during post-hook is silently ignored. The monitor thread exits as soon as rsync's read
   loop ends, so any cancel_requested_at set during post/success/failure hooks never reaches
   Hooks::ExecuteService. If hooks can be long-running, they should observe cancellation too (and
   run inside the same process-group / monitor structure).

4. result.canceled can be true even when rsync succeeded. canceled is derived from
   cancel_requested_at.present? only, with no comparison to the exit time. If a user clicks cancel
   just as rsync finishes cleanly, the run is marked canceled even though all bytes were copied.
   Tighten to "cancel requested and process exited via signal", or compare timestamps.

5. Pre-hook cancel does not notify. When the pre-hook returns canceled: true, the run is
   no notification (intentional, presumably), but it's worth confirming the policy is "no
   notification (intentional, presumably), but it's worth confirming the policy is "no notification
   on cancel ever" and applying it uniformly. If "canceled" should notify, the event name needs to
   exist.

6. Double "failure" notification on certain raise paths. The inner rescue StandardError inside
   Tempfile.create enqueues "failure" but does not re-raise, so the outer rescue doesn't trigger. But
   notification (intentional, presumably), but it's worth confirming the policy is "no notification
   on cancel ever" and applying it uniformly. If "canceled" should notify, the event name needs to
   exist.

6. Double "failure" notification on certain raise paths. The inner rescue StandardError inside
   Tempfile.create enqueues "failure" but does not re-raise, so the outer rescue doesn't trigger. Bu
   no notification (intentional, presumably), but it's worth confirming the policy is "no
   notification on cancel ever" and applying it uniformly. If "canceled" should notify, the event
   name needs to exist.

6. Double "failure" notification on certain raise paths. The inner rescue StandardError inside
   Tempfile.create enqueues "failure" but does not re-raise, so the outer rescue doesn't trigger.
   But if job_run.complete!/mark_failed! itself raises after enqueue_notifications(:success) has
   already fired, the rescue will fire a second "failure" notification. Consider guarding
   enqueue_notifications on a "notification already sent for this run" flag, or move notification
   dispatch out of the rescue paths.

Design remarks

7. Stale pid is never cleared. After completion the PID column still holds the dead pid. Nothing
   currently relies on it post-exit, but it's a footgun if any future code (e.g. a "kill orphans on
   boot" task) reads it. Clear it on terminal transitions.

8. Worker crash recovery is unaddressed. If the worker process is killed hard between start! and
   the terminal transition, the JobRun is stuck in running forever with last_heartbeat_at going
   stale. The heartbeat column exists but nothing seems to reap stale runs. Worth a small scheduled
   task: "if running and heartbeat older than N×interval, mark errored".

9. Cancellation latency is up to CANCEL_MONITOR_INTERVAL (5 s) plus DB poll. Acceptable, but if
   you wanted faster cancel you could NOTIFY from CancelService and have the monitor LISTEN, or
   signal via a file/pipe. Not urgent.

10. ActiveStorage attach uses a tempfile that's deleted on block exit. Tempfile.create deletes
    the file when the block returns. output.attach(io: file) must therefore complete the upload
    synchronously before the block ends. With the default disk service that's fine; if you ever move
    to a service with async/direct upload this becomes a silent data-loss bug. Worth a comment, or
    attach after the block via the saved path.

11. enqueue_notifications wait of 5 s to dodge "uncommitted transaction" is a smell. The comment
    admits it. The clean fix is after_commit callbacks (or ActiveRecord::Base.transaction { ... }
    boundaries) rather than a sleep-based hope. Brittle under load.

12. Configuration.get("hooks") gates both the pre-hook and the post-hook block. If an operator
    toggles hooks off mid-run (between pre and post), behavior is inconsistent. Read once at the
    start of call and cache.

13. Minor: enqueue_notifications(job_run, ...) re-resolves job_run.job.job_notifications though
    @job is already memoized; pass via the cached attr. Cosmetic.

Questions I need answered

- Hook failures and final status (#1): is the intent that a failing post-hook should override
  rsync's outcome, or is the rsync result the source of truth?
- Cancel notifications (#5): should canceled runs notify? Today they don't.
- Stale running recovery (#8): is there a reaper I missed, or is this currently unhandled?
- bytes_copied semantics on tick: before_transition on: :tick writes kwargs[:bytes_copied]
  unconditionally — if a single status line is missing the field, would it nil out? Worth checking
  Rsync::Progress guarantees.

1. Add the following columns to the `job_runs` table:
   - `pre_hook_status`: string, nullable, enum (possible values: "success", "failure", "errored")
   - `pre_hook_exit_status`: integer, nullable
   - `pre_hook_error_class`: string, nullable
   - `pre_hook_error_message`: text, nullable
   - `post_hook_status`: string, nullable, enum (possible values: "success", "failure", "errored")
   - `post_hook_exit_status`: integer, nullable
   - `post_hook_error_class`: string, nullable
   - `post_hook_error_message`: text, nullable
   - `success_hook_status`: string, nullable, enum (possible values: "success", "failure", "errored")
   - `success_hook_exit_status`: integer, nullable
   - `success_hook_error_class`: string, nullable
   - `success_hook_error_message`: text, nullable
   - `failure_hook_status`: string, nullable, enum (possible values: "success", "failure", "errored")
   - `failure_hook_exit_status`: integer, nullable
   - `failure_hook_error_class`: string, nullable
   - `failure_hook_error_message`: text, nullable
  Update the `execute_service` to set columns for the respective hook where appropriate:
   - Set status to "success" when the respective hook command exits successfully
   - Set status to "failure", and set the exit status when the respective hook command exits with a non-zero exit status
   - Set status to "errored", and set error class and error message when the respective hook command raises an exception
  Make sure the output of the `pre_hook` and `post_hook` is captured and attached to the job run
  Additionally, when a `pre_hook` fails:
   - Set job run status to "failure"
   - Do not continue with the rsync process (early exit)
  Update the service classes and corresponding tests to reflect the changes.

## Architectural review of the execution/cancellation process

Review and re-architect the execution/cancellation process to address the following feedback:

- Drop the cancellation monitor thread
- Drop the cancellation check in the read loop
- Add a `cancelling` state to the job runs state machine
- Let the cancel service do the following:
  - Early return if the job cannot be canceled
  - Transition the job run to `cancelling`
  - Schedule a cancellation job that:
    - Sets the job run status to `cancelling`
    - Sets the `cancel_requested_at` timestamp on the job run
    - Sends a SIGTERM signal to the `pid` stored on the job run
- Let the execute service do the following:
  - Early return if the job run cannot be started
  - Transition the job run to `running`
  - Start the pre-hook (if any) and set the `pid` of the process on the job run
    - Read and capture the output of the pre-hook process
    - When the process exits with a non-zero exit status, transition the job run to `failure`
    - Clear the `pid` of the process on the job run
  - Check if the job run was canceled, and if so, transition the job run to `cancelled`
  - Start the rsync process and set the `pid` of the rsync process on the job run (if the pre-hook was successful)
    - Read and capture the output of the rsync process
    - When the process exits with a non-zero exit status, transition the job run to `failure` OR to `cancelled` if the job run was canceled
    - Clear the `pid` of the process on the job run
  - Check if the job run was canceled, and if so, transition the job run to `cancelled` and abort
  - Start the post-hook (if any) and set the `pid` of the process on the job run
    - Read and capture the output of the post-hook process
    - When the process exits with a non-zero exit status, transition the job run to `failure` OR to `cancelled` if the job run was canceled
    - Clear the `pid` of the process on the job run
  - Check if the job run was canceled, and if so, transition the job run to `cancelled` and abort
  - Start the success hook (if any and the job succeeded) and set the `pid` of the process on the job run
    - Read and capture the output of the success hook process
    - Clear the `pid` of the process on the job run
  - Start the failure hook (if any and the job failed) and set the `pid` of the process on the job run
    - Read and capture the output of the failure hook process
    - Clear the `pid` of the process on the job run
- Move the notification logic to the job run state machine as side effect of the transitions.

### Requirements

#### General requirements

1. Regardless of the exit status of the rsync process, the output of the rsync process should be captured and attached to the job run.

#### Hooks

If hooks are configured, the following requirements apply:

1. The pre-hook should be run before the rsync process starts.
2. The post-hook should be run after the rsync process completes.
3. The success hook should be run if the rsync process completes successfully.
4. The failure hook should be run if the rsync process fails.

5. If the pre-hook fails, the rsync process should not be started.
6. If the pre-hook fails, the status of the job run should be set to "failure".
7. If the post-, success, or failure hooks fail, the status of the job run should not be affected.

#### Cancellation

1. Cancellation can be requested by the user at any time during the execution.
2. Cancellation is asynchronous and always executed on the same worker as the job run execution.
3. If a cancellation is requested when a pre-, post-, success, or failure hooks is running, the system should cancel the process of the hook.
4. If a cancellation is requested while the rsync process is running, the system should cancel the rsync process.
5. The cancellation should happen within 5 seconds of the user request.

Cancellation is implemented as follows:
1. System executes pre-hook, rsync process, post-hook, success hook, and failure hook, and sets the `pid` of each process on the job runs table
2. User request cancellation, system schedules a cancellation job that:
  - Sets the job run status to `cancelling` 
  - Sets the `cancel_requested_at` timestamp on the job run
  - Sends a SIGTERM signal to the `pid` stored on the job run

#### Heartbeat

#### Notifications

If notifications are configured, the following requirements apply:
