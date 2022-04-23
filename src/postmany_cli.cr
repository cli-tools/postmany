require "./postmany"
include Postmany

uri : URI? = nil
workers : Int32 = 1
silent : Bool = false
progress : Bool = true
method : String = "POST"

c_filename = Channel(String).new # channel with files
c_count_in = Channel(Symbol).new # :ok or :skipped for each filename
c_count_out = Channel(Int32).new # count of :ok :skipped
c_progress = Channel(String).new
c_output = Channel(OutputTuple).new

static_headers = Hash(String, String).new

option_parser = OptionParser.parse do |parser|
  parser.banner = "Usage: postmany [OPTIONS] [ENDPOINT]"
  parser.on("-w WORKERS", "--workers=WORKERS", "number of workers (10)") { |arg| workers = Int32.new arg }
  parser.on("-s", "--silent", "no verbose output") { silent = true }
  parser.on("--no-progress", "disable progress meter") { progress = false }
  parser.on("-X METHOD", "--request=METHOD", "HTTP method: POST, PUT or GET (POST)") { |arg| method = arg.upcase }
  parser.on("-H HEADER", "--header=HEADER", "HTTP header") { |arg| k, v = arg.split(":"); static_headers[k] = v }
  parser.on("-h", "--help", "show help") { STDERR.puts parser; exit(0) }
  parser.on("--version", "show version") { puts "Postmany #{VERSION}"; exit(0) }
  parser.invalid_option do |flag|
    STDERR.puts "postmany: Unrecognized option '#{flag}'"
    STDERR.puts parser
    exit(2)
  end
end

if ARGV.size > 0
  uri = URI.parse ARGV[0]
end

if uri.nil?
  STDERR.puts "Error: URL was not provided"
  exit 1
end

if !Set{"GET", "POST", "PUT"}.includes? method
  STDERR.puts "Error: MODE must be either POST, PUT or GET"
  exit 1
end

(0..workers - 1).each do |worker_id|
  spawn processor_worker(worker_id, uri, method, silent, static_headers, c_filename, c_count_in)
end
spawn processor_count(c_count_in, c_count_out, c_progress, method)
if progress
  spawn processor_progress(c_progress, c_output)
else
  spawn processor_drop(c_progress)
end
spawn processor_output(c_output)

file_count = 0
# NOTE: need to spawn because c_count_out will block unless we start reading it
ingest = spawn do
  loop do
    filename = gets
    break if filename.nil?
    file_count += 1
    c_filename.send filename
  end
end
count = 0
loop do
  break if count == file_count && ingest.dead?
  count = c_count_out.receive?
  sleep (0.1).seconds
end
c_filename.close
c_count_in.close
c_count_out.close
#c_error.close
Fiber.yield
