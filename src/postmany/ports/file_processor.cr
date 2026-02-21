abstract class Postmany::Ports::FileProcessor
  abstract def call(filename : String, context : Postmany::Domain::TransferContext) : Postmany::Domain::Outcome
end
