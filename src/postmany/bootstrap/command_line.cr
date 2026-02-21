class Postmany::Bootstrap::ExitRequested < Exception
  getter code : Int32
  getter target : IO

  def initialize(@code : Int32, message : String, @target : IO)
    super(message)
  end
end

class Postmany::Bootstrap::CommandLine
  def parse(argv : Array(String), stdout : IO, stderr : IO) : Postmany::Domain::TransferContext
    workers = 1
    silent = false
    progress = true
    method_raw = "POST"
    static_headers = Hash(String, String).new

    parser = OptionParser.new
    parser.banner = "Usage: postmany [OPTIONS] [ENDPOINT]"
    parser.on("-w WORKERS", "--workers=WORKERS", "number of workers (10)") { |arg| workers = Int32.new(arg) }
    parser.on("-s", "--silent", "no verbose output") { silent = true }
    parser.on("--no-progress", "disable progress meter") { progress = false }
    parser.on("-X METHOD", "--request=METHOD", "HTTP method: POST, PUT or GET (POST)") { |arg| method_raw = arg.upcase }
    parser.on("-H HEADER", "--header=HEADER", "HTTP header") do |arg|
      key, value = parse_header(arg)
      static_headers[key] = value
    end
    parser.on("-h", "--help", "show help") { raise Postmany::Bootstrap::ExitRequested.new(0, parser.to_s, stderr) }
    parser.on("--version", "show version") { raise Postmany::Bootstrap::ExitRequested.new(0, "Postmany #{Postmany::VERSION}", stdout) }
    parser.invalid_option do |flag|
      message = "postmany: Unrecognized option '#{flag}'\n#{parser}"
      raise Postmany::Bootstrap::ExitRequested.new(2, message, stderr)
    end

    parser.parse(argv)

    if workers < 1
      raise Postmany::Bootstrap::ExitRequested.new(1, "Error: WORKERS must be at least 1", stderr)
    end

    endpoint_arg = argv[0]?
    if endpoint_arg.nil?
      raise Postmany::Bootstrap::ExitRequested.new(1, "Error: URL was not provided", stderr)
    end

    method = Postmany::Domain::TransferMethod.from_string(method_raw)
    if method.nil?
      raise Postmany::Bootstrap::ExitRequested.new(1, "Error: MODE must be either POST, PUT or GET", stderr)
    end

    endpoint = Postmany::Domain::Endpoint.new(URI.parse(endpoint_arg))
    Postmany::Domain::TransferContext.new(endpoint, method, workers, silent, progress, static_headers)
  end

  private def parse_header(raw : String) : {String, String}
    parts = raw.split(":", 2)
    if parts.size != 2
      {raw, ""}
    else
      {parts[0], parts[1]}
    end
  end
end
