class Postmany::Adapters::IOFilenameSource < Postmany::Ports::FilenameSource
  def initialize(@io : IO)
  end

  def next_filename : String?
    @io.gets
  end
end
