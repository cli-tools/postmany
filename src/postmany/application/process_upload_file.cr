class Postmany::Application::ProcessUploadFile
  SUCCESS_CODES = Set{200, 201, 202}

  def initialize(@filesystem : Postmany::Ports::Filesystem,
                 @mime_resolver : Postmany::Ports::MimeResolver,
                 @http : Postmany::Ports::HttpTransport,
                 @sleeper : Postmany::Ports::Sleeper,
                 @output : Postmany::Ports::Output)
  end

  def call(filename : String, context : Postmany::Domain::TransferContext) : Postmany::Domain::Outcome
    loop do
      content = read_content(filename)
      return Postmany::Domain::Outcome::Skipped if content.nil?

      path = if context.method.put?
               context.endpoint.path_for(context.method, filename)
             else
               context.endpoint.path_for(context.method)
             end

      request = Postmany::Ports::HttpRequest.new(
        method: context.method,
        path: path,
        query: context.endpoint.query,
        headers: upload_headers(context.static_headers, filename),
        body: content
      )

      response = @http.perform(request)
      if SUCCESS_CODES.includes?(response.status_code)
        @output.file_processed(filename, context.silent)
        return Postmany::Domain::Outcome::Ok
      end

      @output.error("#{filename}: HTTP POST error #{response.status_code}")
      @sleeper.sleep(1)
    rescue ex
      @output.error("#{filename}: #{ex}")
      return Postmany::Domain::Outcome::Skipped
    end
  end

  private def read_content(filename : String) : String?
    @filesystem.read(filename)
  rescue File::NotFoundError
    @output.error("#{filename}: file not found")
    nil
  end

  private def upload_headers(static_headers : Hash(String, String), filename : String) : Hash(String, String)
    headers = static_headers.dup
    content_type = resolve_content_type(filename)
    headers["Content-Type"] = content_type unless content_type.nil?
    headers
  end

  private def resolve_content_type(filename : String) : String?
    content_type = @mime_resolver.from_filename(filename)
    return "binary/octet-stream" if content_type.nil?
    content_type
  rescue
    "binary/octet-stream"
  end
end
