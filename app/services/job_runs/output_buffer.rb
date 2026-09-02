# frozen_string_literal: true

module JobRuns
  # Buffers output for a running job run in the cache
  class OutputBuffer
    # Interval after which to flush the output buffer to cache
    FLUSH_INTERVAL = 10.seconds

    # Buffer length after which to flush the output buffer to cache
    FLUSH_BYTES = 8.kilobytes

    # Cache expiration interval
    EXPIRES_IN = 1.day

    attr_reader :job_run,
                :buffer,
                :last_flush_at

    def initialize(job_run)
      @job_run = job_run
      @buffer = +""
      @last_flush_at = Time.zone.now
    end

    def <<(content)
      buffer << content

      flush if due?
    end

    def flush
      return if buffer.empty?

      Rails.cache.write(self.class.cache_key(job_run), self.class.read(job_run) + buffer, expires_in: EXPIRES_IN)

      @buffer = +""
      @last_flush_at = Time.zone.now
    end

    def self.read(job_run)
      Rails.cache.read(cache_key(job_run)) || ""
    end

    def self.clear(job_run)
      Rails.cache.delete(cache_key(job_run))

      job_run
    end

    def self.attach(job_run)
      content = read(job_run)

      if content.present? && !job_run.output.attached?
        job_run.output.attach(
          io: StringIO.new(content),
          filename: "job_run_#{job_run.sequence}.log",
          content_type: "text/plain",
        )
      end

      clear(job_run)
    end

    def self.cache_key(job_run)
      "job_runs/#{job_run.id}/output_buffer"
    end

    private

    def due?
      buffer.bytesize >= FLUSH_BYTES || Time.zone.now >= last_flush_at + FLUSH_INTERVAL
    end
  end
end
