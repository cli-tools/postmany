require "http/client"
require "uri"
require "mime"
require "option_parser"
require "colorize"

module Postmany
  VERSION = "v0.2.1"

  c_filename = Channel(String).new
  c_ok = Channel(String).new
  c_info = Channel(String).new
  c_error = Channel(String).new
  c_output = Channel({Colorize::Object(String), Bool}).new
  c_stdout = Channel(String).new
  # c_output = Channel({String, Bool}).new
  uri : URI? = nil
  count : Int32 = 0
  skipped : Int32 = 0
  workers : Int32 = 10
  verbose : Bool = false
  progress : Bool = true
  method : String = "POST"

  # TODO: Add reasonable options

  static_headers = Hash(String,String).new

  option_parser = OptionParser.parse do |parser|
    parser.banner = "Usage: postmany [OPTIONS] [ENDPOINT]"
    parser.on("-w WORKERS", "--workers=WORKERS", "number of workers (10)") { |arg| workers = Int32.new arg }
    parser.on("-v", "--verbose", "verbose output (false)") { verbose = true }
    parser.on("--no-progress", "disable progress meter") { progress = false }
    parser.on("-X METHOD", "--request=METHOD", "HTTP method: POST, PUT or GET (POST)") { |arg| method = arg.upcase }
    parser.on("-H HEADER", "--header=HEADER", "HTTP header") { |arg| k, v = arg.split(":"); static_headers[k] = v;}
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

  path = uri.as(URI).@path
  query = uri.as(URI).@query
  if path == ""
    path = "/"
  end
  if !path.ends_with?("/")
    path += "/"
  end


  workers.times do |worker_id|
    pre = "[#{worker_id.to_s.rjust(3)}]"
    spawn do
      begin
        client = HTTP::Client.new uri.as(URI)
        client.before_request do |request|
          static_headers.each { |k,v| request.headers[k] = v }
        end
      rescue ex
        STDERR.puts "#{pre}: HTTP client could not connect to #{uri}: #{ex}"
        exit 2
      end
      loop do
        filename = c_filename.receive?
        break if filename.nil?
        if method == "POST" || method == "PUT"
          begin
            content = File.read(filename)
          rescue File::NotFoundError
            c_error.send "#{pre}: File not found error: #{filename}"
            skipped += 1
            next
          end
          begin
            content_type = MIME.from_filename(filename)
          rescue
            content_type = "binary/octet-stream"
          end
          headers = if content_type.nil?
                      skipped += 1
                      nil
                    else
                      HTTP::Headers{"Content-Type" => content_type}
                    end
          begin
            if method == "POST"
              if query.nil?
                response = client.post path, headers, body = content
              else
                response = client.post "#{path}?#{query}", headers, body = content
              end
            else # method == PUT
              if query.nil?
                !p path, filename
                response = client.put "#{path}#{filename}", headers, body = content
              else
                !p path, filename, query
                response = client.put "#{path}#{filename}?#{query}", headers, body = content
              end
            end
            if Set{200, 201, 202}.includes? response.status_code
              c_ok.send "#{pre}: OK: #{filename}"
              c_stdout.send filename
            else
              c_error.send "#{pre} HTTP POST error #{response.status_code}: #{filename}"
              c_filename.send filename
              sleep 1
            end
          rescue ex : ArgumentError
            STDERR.puts "exception: #{ex}"
            skipped += 1
          rescue ex : Socket::Addrinfo::Error
            STDERR.puts "#{pre}: Error: #{ex}"
            skipped += 1
          end
        else # method GET
          begin
            if query
              response = client.get("#{path}#{filename}?#{query}")
            else
              response = client.get("#{path}#{filename}")
            end
            if Set{200}.includes? response.status_code
              content = response.body
              begin
                Dir.mkdir_p Path[filename].dirname
                File.write(filename, content)
                # puts "OK wrote the stuff to disk"
                c_ok.send "#{pre}: OK: #{filename}"
              rescue ex
                # fail
                puts "Error: #{ex}"
                skipped += 1
              end
              # c_ok.send "#{pre}: OK: #{filename}"
              c_stdout.send filename
            else
              c_error.send "#{pre} HTTP GET error #{response.status_code}: #{filename}"
              c_filename.send filename
              sleep 1
            end
          rescue ex : ArgumentError
            STDERR.puts "exception: #{ex}"
            skipped += 1
          rescue ex : Socket::Addrinfo::Error
            STDERR.puts "#{pre}: Error: #{ex}"
            skipped += 1
          end
        end
      end
      if verbose
        c_info.send "#{pre}: Stopped"
      end
    end
  end

  # c_stdout processor

  spawn do
    loop do
      str = c_stdout.receive?
      break if str.nil?
      puts str
    end
  end

  # c_output processor

  spawn do
    dirty = false
    loop do
      output = c_output.receive?
      break if output.nil?
      output, keep = output
      if dirty && keep
        STDERR.puts
        STDERR.puts output
        dirty = false
      elsif dirty && !keep
        STDERR.print output
        STDERR.print "\r"
      elsif !dirty && keep
        STDERR.puts output
      else # !dirty && !keep
        STDERR.print output
        STDERR.print "\r"
        dirty = true
      end
    end
  end

  # c_error processor

  spawn do
    loop do
      err = c_error.receive?
      break if err.nil?
      c_output.send({err.colorize(:red), true})
    end
  end

  # c_info processor

  spawn do
    loop do
      info = c_info.receive?
      break if info.nil?
      c_output.send({info.colorize(:cyan), true})
    end
  end

  # c_ok processor

  spawn do
    exit if !progress
    count = 0
    t0 = Time.utc
    loop do
      begin
        ok = c_ok.receive
        count += 1
        t1 = Time.utc
        if (t1 - t0).seconds < 2
          next
        else
          t0 = t1
        end
        case method
        when "GET"
          c_output.send({"OK: #{count} files received; #{skipped} skipped".colorize(:green), false})
        when "POST", "PUT"
          c_output.send({"OK: #{count} files sent; #{skipped} skipped".colorize(:green), false})
        end
      rescue Channel::ClosedError
        break
      end
    end
    case method
    when "GET"
      c_output.send({"OK: #{count} files received; #{skipped} skipped".colorize(:green), true})
    else
      c_output.send({"OK: #{count} files sent; #{skipped} skipped".colorize(:green), true})
    end
  end

  # Ingest loop

  file_count = 0
  loop do
    filename = gets
    break if filename.nil?
    file_count += 1
    c_filename.send filename
  end
  c_filename.close
  # TODO: Use messages instead of a shared variable w/spinlock
  loop do
    break if count + skipped == file_count
    Fiber.yield
  end
  sleep 0.1
  c_ok.close
  c_info.close
  c_error.close
  Fiber.yield
end
