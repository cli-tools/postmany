abstract class Postmany::Ports::Filesystem
  abstract def read(path : String) : String
  abstract def write(path : String, content : String) : Nil
  abstract def ensure_parent_dir(path : String) : Nil
end
