require "http/client"
require "uri"
require "mime"
require "option_parser"
require "colorize"

module Postmany
  VERSION        = "v0.3.3"
  UPDATE_SECONDS = 2

  alias OutputTuple = {String | Colorize::Object(String), Bool, IO}
  alias OutputChannel = Channel(OutputTuple)

  def processor_worker(worker_id : Int,
                       uri : URI,
                       method : String,
                       silent : Bool,
                       static_headers : Hash(String, String),
                       c_filename : Channel(String),
                       c_count : Channel(Symbol))
    path = uri.as(URI).@path
    query = uri.as(URI).@query
    path = "/" if path == ""
    path += "/" if Set{"GET", "PUT"}.includes?(method) && !path.ends_with?("/")
    # pre = "[#{worker_id.to_s.rjust(3)}]"
    spawn do
      begin
        client = HTTP::Client.new uri.as(URI)
        client.before_request do |request|
          static_headers.each { |k, v| request.headers[k] = v }
        end
      rescue ex
        STDERR.puts "worker #{worker_id}: HTTP client could not connect to #{uri}: #{ex}"
        exit 2
      end
      loop do
        filename = c_filename.receive?
        break if filename.nil?
        loop do
          if method == "POST" || method == "PUT"
            begin
              content = File.read(filename)
            rescue File::NotFoundError
              STDERR.puts "#{filename}: file not found".colorize(:red)
              c_count.send :skipped
              break
            end
            begin
              content_type = MIME.from_filename(filename)
            rescue
              content_type = "binary/octet-stream"
            end
            headers = if content_type.nil?
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
                  #!p path, filename
                  response = client.put "#{path}#{filename}", headers, body = content
                else
                  #!p path, filename, query
                  response = client.put "#{path}#{filename}?#{query}", headers, body = content
                end
              end
              if Set{200, 201, 202}.includes? response.status_code
                c_count.send :ok
                puts filename unless silent
              else
                STDERR.puts "#{filename}: HTTP POST error #{response.status_code}"
                sleep 1
                next # try loop again with the same file
              end
            rescue ex
              # ex : ArgumentError | Socket::Addrinfo:Error | Socket::ConnectError | Exception
              STDERR.puts "#{filename}: #{ex}"
              c_count.send :skipped
              break
            else
              break
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
                rescue ex
                  STDERR.puts "#{filename}: #{ex}"
                  c_count.send :skipped
                  break
                else
                  c_count.send :ok
                  puts filename unless silent
                  break
                end
              else
                STDERR.puts "#{filename}: HTTP GET error #{response.status_code}"
                if 400 <= response.status_code < 500
                  c_count.send :skipped
                  break
                else
                  sleep 1
                end
              end
            rescue ex : ArgumentError
              STDERR.puts "#{filename}: #{ex}"
              c_count.send :skipped
              break
            rescue ex : Socket::Addrinfo::Error
              STDERR.puts "#{filename}: #{ex}"
              c_count.send :skipped
              break
            rescue ex
              STDERR.puts "#{filename}: #{ex}"
              c_count.send :skipped
              break
            end
          end
        end
      end
    end
  end

  def processor_output(c_output : Channel(OutputTuple))
    dirty = false
    loop do
      output = c_output.receive?
      break if output.nil?
      output, keep, io = output
      if dirty && keep
        io.puts
        io.puts output
        dirty = false
      elsif dirty && !keep
        io.print output
        io.print "\r"
      elsif !dirty && keep
        io.puts output
      else # !dirty && !keep
        io.print output
        io.print "\r"
        dirty = true
      end
    end
  end

  def processor_error(c_error : Channel(String), c_output : Channel(OutputTuple))
    loop do
      err = c_error.receive?
      break if err.nil?
      c_output.send({err.colorize(:red), true, STDERR})
    end
  end

  def processor_drop(c_in : Channel(String))
    loop do
      msg = c_in.receive?
      break if msg.nil?
    end
  end

  def processor_progress(c_in : Channel(String), c_out : Channel(OutputTuple))
    loop do
      msg = c_in.receive?
      break if msg.nil?
      c_out.send({msg.colorize(:green), true, STDERR})
    end
  end

  def processor_count(c_in : Channel(Symbol), c_out : Channel(Int32), c_progress : Channel(String), method : String)
    n_ok = n_skipped = n_sum = n_last = 0
    t0 = Time.utc
    loop do
      begin
        case c_in.receive
        when :ok
          n_ok += 1
        when :skipped
          n_skipped += 1
        end
        n_sum += 1
        c_out.send n_sum
        t1 = Time.utc
        if (t1 - t0).seconds < UPDATE_SECONDS
          next
        else
          t0 = t1
        end
        case method
        when "GET"
          c_progress.send "#{n_ok} files received; #{n_skipped} skipped"
        when "POST", "PUT"
          c_progress.send "#{n_ok} files sent; #{n_skipped} skipped"
        end
        n_last = n_sum
      rescue Channel::ClosedError
        break
      end
    end
    if n_last < n_sum
      n_last = n_sum
      case method
      when "GET"
        c_progress.send "#{n_ok} files received; #{n_skipped} skipped"
      else
        c_progress.send "#{n_ok} files sent; #{n_skipped} skipped"
      end
    end
  end
end
