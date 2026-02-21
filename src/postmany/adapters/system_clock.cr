class Postmany::Adapters::SystemClock < Postmany::Ports::Clock
  def now : Time
    Time.utc
  end
end
