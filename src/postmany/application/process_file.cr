class Postmany::Application::ProcessFile < Postmany::Ports::FileProcessor
  def initialize(@upload : ProcessUploadFile, @download : ProcessDownloadFile)
  end

  def call(filename : String, context : Postmany::Domain::TransferContext) : Postmany::Domain::Outcome
    if context.method.get?
      @download.call(filename, context)
    else
      @upload.call(filename, context)
    end
  end
end
