abstract class Postmany::Ports::Output
  abstract def file_processed(filename : String, silent : Bool) : Nil
  abstract def error(message : String) : Nil
  abstract def progress(message : String) : Nil
end
