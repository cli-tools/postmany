require "http/client"
require "uri"
require "mime"
require "option_parser"
require "colorize"

module Postmany
  VERSION = "0.1.0"
  WORKERS = 16

  c_filename = Channel(String?).new
  c_ok = Channel(String?).new
  c_info = Channel(String?).new
  c_error = Channel(String?).new
  c_output = Channel({Colorize::Object(String), Bool}).new
  # c_output = Channel({String, Bool}).new
  uri : URI? = nil
  count : Int32 = 0
  skipped : Int32 = 0

  # TODO: Add reasonable options

  option_parser = OptionParser.parse do |parser|
    # parser.on "URL", "Request URL" do |url|
    #  uri = URI.parse url
    # end
  end

  if ARGV.size > 0
    uri = URI.parse ARGV[0]
  end

  if uri.nil?
    STDERR.puts "Error: an URL was not provided"
    exit 1
  end

  path = uri.as(URI).@path
  query = uri.as(URI).@query
  if !query.nil?
    path = "#{path}?#{query}"
  end

  WORKERS.times do |worker_id|
    client = HTTP::Client.new uri.as(URI)
    # TODO: Use a built-in Int32 -> Hex String method
    pre = case worker_id
          when 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
            "[#{worker_id}]"
          when 10, 11, 12, 13, 14, 15
            "[#{'A' + worker_id - 10}]"
          end
    spawn do
      loop do
        filename = c_filename.receive
        if filename.nil?
          break
        else
          begin
            content = File.read(filename)
          rescue File::NotFoundError
            c_error.send "#{pre}: file not found error: #{filename}"
            skipped += 1
            next
          end
          content_type = MIME.from_filename(filename)
          headers = if content_type.nil?
                      nil
                    else
                      HTTP::Headers{"Content-Type" => MIME.from_filename(filename)}
                    end
          response = client.post path, headers, body = content
          if Set{200, 201, 202}.includes? response.status_code
            c_ok.send "#{pre}: OK: #{filename}"
          else
            c_error.send "#{pre} HTTP POST error #{response.status_code}: #{filename}"
            c_filename.send filename
            sleep 1
          end
        end
      end
      c_info.send "#{pre}: stopped"
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
  WORKERS.times do
    c_filename.send(nil)
  end
  sleep 0.1
  c_ok.send nil
  c_info.send nil
  c_error.send nil
  Fiber.yield
end
