abstract class Postmany::Ports::WorkerPool
  abstract def run(worker_count : Int32,
                   source : FilenameSource,
                   process : Proc(String, Postmany::Domain::Outcome),
                   &on_outcome : Postmany::Domain::Outcome -> Nil) : Nil
end
