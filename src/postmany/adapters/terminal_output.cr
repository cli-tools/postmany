class Postmany::Adapters::TerminalOutput < Postmany::Ports::Output
  def initialize(@stdout : IO = STDOUT, @stderr : IO = STDERR)
  end

  def file_processed(filename : String, silent : Bool) : Nil
    return if silent
    @stdout.puts(filename)
  end

  def error(message : String) : Nil
    @stderr.puts(message.colorize(:red))
  end

  def progress(message : String) : Nil
    @stderr.puts(message.colorize(:green))
  end
end
