class Postmany::Application::ProcessDownloadFile
  SUCCESS_CODES = Set{200}

  def initialize(@filesystem : Postmany::Ports::Filesystem,
                 @http : Postmany::Ports::HttpTransport,
                 @sleeper : Postmany::Ports::Sleeper,
                 @output : Postmany::Ports::Output)
  end

  def call(filename : String, context : Postmany::Domain::TransferContext) : Postmany::Domain::Outcome
    loop do
      request = Postmany::Ports::HttpRequest.new(
        method: context.method,
        path: context.endpoint.path_for(context.method, filename),
        query: context.endpoint.query,
        headers: context.static_headers,
        body: nil
      )

      response = @http.perform(request)
      if SUCCESS_CODES.includes?(response.status_code)
        return store_file(filename, response.body, context.silent)
      end

      @output.error("#{filename}: HTTP GET error #{response.status_code}")
      return Postmany::Domain::Outcome::Skipped if response.status_code >= 400 && response.status_code < 500

      @sleeper.sleep(1)
    rescue ex
      @output.error("#{filename}: #{ex}")
      return Postmany::Domain::Outcome::Skipped
    end
  end

  private def store_file(filename : String, content : String, silent : Bool) : Postmany::Domain::Outcome
    @filesystem.ensure_parent_dir(filename)
    @filesystem.write(filename, content)
    @output.file_processed(filename, silent)
    Postmany::Domain::Outcome::Ok
  rescue ex
    @output.error("#{filename}: #{ex}")
    Postmany::Domain::Outcome::Skipped
  end
end
