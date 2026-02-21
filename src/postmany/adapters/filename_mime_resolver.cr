class Postmany::Adapters::FilenameMimeResolver < Postmany::Ports::MimeResolver
  def from_filename(filename : String) : String?
    MIME.from_filename(filename)
  end
end
