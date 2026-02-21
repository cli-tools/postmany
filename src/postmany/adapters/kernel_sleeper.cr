class Postmany::Adapters::KernelSleeper < Postmany::Ports::Sleeper
  def sleep(seconds : Int32) : Nil
    ::sleep(seconds.seconds)
  end
end
