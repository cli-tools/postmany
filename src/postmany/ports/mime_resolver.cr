abstract class Postmany::Ports::MimeResolver
  abstract def from_filename(filename : String) : String?
end
