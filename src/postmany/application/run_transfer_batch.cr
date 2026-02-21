class Postmany::Application::RunTransferBatch
  def initialize(@worker_pool : Postmany::Ports::WorkerPool,
                 @processor : Postmany::Ports::FileProcessor,
                 @output : Postmany::Ports::Output,
                 @clock : Postmany::Ports::Clock,
                 @update_seconds : Int32 = Postmany::UPDATE_SECONDS)
  end

  def call(source : Postmany::Ports::FilenameSource, context : Postmany::Domain::TransferContext) : Postmany::Domain::BatchResult
    ok = 0
    skipped = 0
    total = 0
    last_reported_total = 0
    t0 = @clock.now

    process = ->(filename : String) { @processor.call(filename, context) }

    @worker_pool.run(context.workers, source, process) do |outcome|
      case outcome
      when Postmany::Domain::Outcome::Ok
        ok += 1
      when Postmany::Domain::Outcome::Skipped
        skipped += 1
      end
      total += 1

      next unless context.progress

      t1 = @clock.now
      if (t1 - t0).seconds >= @update_seconds
        t0 = t1
        @output.progress(progress_message(context.method, ok, skipped))
        last_reported_total = total
      end
    end

    if context.progress && last_reported_total < total
      @output.progress(progress_message(context.method, ok, skipped))
    end

    Postmany::Domain::BatchResult.new(ok, skipped, total)
  end

  private def progress_message(method : Postmany::Domain::TransferMethod, ok : Int32, skipped : Int32) : String
    if method.get?
      "#{ok} files received; #{skipped} skipped"
    else
      "#{ok} files sent; #{skipped} skipped"
    end
  end
end
