class Postmany::Adapters::FiberWorkerPool < Postmany::Ports::WorkerPool
  def run(worker_count : Int32,
          source : Postmany::Ports::FilenameSource,
          process : Proc(String, Postmany::Domain::Outcome),
          &on_outcome : Postmany::Domain::Outcome -> Nil) : Nil
    filename_channel = Channel(String).new
    outcome_channel = Channel(Postmany::Domain::Outcome).new

    ingest = spawn do
      loop do
        filename = source.next_filename
        break if filename.nil?
        filename_channel.send(filename)
      end
      filename_channel.close
    end

    workers = Array(Fiber).new(worker_count)
    worker_count.times do
      workers << spawn do
        loop do
          filename = filename_channel.receive?
          break if filename.nil?
          outcome = process.call(filename)
          outcome_channel.send(outcome)
        end
      end
    end

    spawn do
      until ingest.dead?
        Fiber.yield
      end
      workers.each do |worker|
        until worker.dead?
          Fiber.yield
        end
      end
      outcome_channel.close
    end

    loop do
      outcome = outcome_channel.receive?
      break if outcome.nil?
      on_outcome.call(outcome)
    end
  end
end
