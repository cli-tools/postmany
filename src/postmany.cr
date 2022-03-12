require "http/client"
require "uri"
require "mime"
require "option_parser"
require "colorize"

module Postmany
  VERSION = "0.1.1"

  c_filename = Channel(String?).new
  c_ok = Channel(String?).new
  c_info = Channel(String?).new
  c_error = Channel(String?).new
  c_output = Channel({Colorize::Object(String), Bool}).new
  # c_output = Channel({String, Bool}).new
  uri : URI? = nil
  count : Int32 = 0
  skipped : Int32 = 0
  workers : Int32 = 16
  verbose : Bool = false

  # TODO: Add reasonable options

  option_parser = OptionParser.parse do |parser|
    parser.banner = "Usage: postmany [OPTIONS] [ENDPOINT]"
    parser.on("-w WORKERS", "--workers=WORKERS", "number of workers (16)") { |arg| workers = Int32.new arg }
    parser.on("-v", "--verbose", "verbose output (false)") { verbose = true }
    # parser.on "URL", "Request URL" do |url|
    #  uri = URI.parse url
    # end
    parser.on("-h", "--help", "show help") { STDERR.puts parser; exit(0) }
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

  path = uri.as(URI).@path
  query = uri.as(URI).@query
  if !query.nil?
    path = "#{path}?#{query}"
  end

  workers.times do |worker_id|
    # TODO: Use a built-in Int32 -> Hex String method
    pre = "[#{worker_id.to_s.rjust(3)}]"
    spawn do
      begin
        client = HTTP::Client.new uri.as(URI)
      rescue ex
        STDERR.puts "#{pre}: HTTP client could not connect to #{uri}: #{ex}"
        exit 2
      end
      loop do
        filename = c_filename.receive
        if filename.nil?
          break
        else
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
            response = client.post path, headers, body = content
            if Set{200, 201, 202}.includes? response.status_code
              c_ok.send "#{pre}: OK: #{filename}"
            else
              c_error.send "#{pre} HTTP POST error #{response.status_code}: #{filename}"
              c_filename.send filename
              sleep 1
            end
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

  spawn do
    dirty = false
    loop do
      output, keep = c_output.receive
      if dirty && keep
        puts
        puts output
        dirty = false
      elsif dirty && !keep
        print output
        print "\r"
      elsif !dirty && keep
        puts output
      else # !dirty && !keep
        print output
        print "\r"
        dirty = true
      end
    end
  end

  spawn do
    loop do
      err = c_error.receive
      if err.nil?
        break
      else
        c_output.send({err.colorize(:red), true})
        # c_output.send({err, true})
      end
    end
  end

  spawn do
    loop do
      info = c_info.receive
      if info.nil?
        break
      else
        c_output.send({info.colorize(:cyan), true})
        # c_output.send({info, true})
      end
    end
  end

  spawn do
    count = 0
    loop do
      ok = c_ok.receive
      if ok.nil?
        c_output.send({"OK: #{count} files sent; #{skipped} skipped".colorize(:green), true})
        # c_output.send({"OK: #{count} files sent; #{skipped} skipped", true})
        break
      else
        count += 1
        if verbose
          puts ok
        end
        if count % 100 == 0
          c_output.send({"OK: #{count} files sent; #{skipped} skipped".colorize(:green), false})
          # c_output.send({"OK: #{count} files sent; #{skipped} skipped", false})
        end
      end
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
  # TODO: Use messages instead of a shared variable w/spinlock
  loop do
    break if count + skipped == file_count
    sleep 0.1
  end
  workers.times do
    c_filename.send(nil)
  end
  sleep 0.1
  c_ok.send nil
  c_info.send nil
  c_error.send nil
  Fiber.yield
end
