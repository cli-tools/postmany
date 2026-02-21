class FakeFilesystem < Postmany::Ports::Filesystem
  getter reads = [] of String
  getter writes = {} of String => String
  getter ensured_paths = [] of String

  @read_map : Hash(String, String)
  @read_errors : Hash(String, Exception)

  def initialize(@read_map = {} of String => String,
                 @read_errors = {} of String => Exception)
  end

  def read(path : String) : String
    @reads << path

    if error = @read_errors[path]?
      raise error
    end

    content = @read_map[path]?
    raise File::NotFoundError.new("file not found", file: path) if content.nil?

    content
  end

  def write(path : String, content : String) : Nil
    @writes[path] = content
  end

  def ensure_parent_dir(path : String) : Nil
    @ensured_paths << path
  end
end

class FakeMimeResolver < Postmany::Ports::MimeResolver
  @map : Hash(String, String)

  def initialize(@map = {} of String => String)
  end

  def from_filename(filename : String) : String?
    @map[filename]?
  end
end

class FakeHttpTransport < Postmany::Ports::HttpTransport
  getter requests = [] of Postmany::Ports::HttpRequest

  @steps : Array(Postmany::Ports::HttpResponse | Exception)

  def initialize(@steps = [] of (Postmany::Ports::HttpResponse | Exception))
  end

  def initialize(steps : Array(Postmany::Ports::HttpResponse))
    @steps = steps.map { |item| item.as(Postmany::Ports::HttpResponse | Exception) }
  end

  def initialize(steps : Array(Exception))
    @steps = steps.map { |item| item.as(Postmany::Ports::HttpResponse | Exception) }
  end

  def perform(request : Postmany::Ports::HttpRequest) : Postmany::Ports::HttpResponse
    @requests << request
    step = @steps.shift?
    raise "Unexpected HTTP request with no configured response" if step.nil?

    if step.is_a?(Postmany::Ports::HttpResponse)
      step
    else
      raise step.as(Exception)
    end
  end
end

class FakeSleeper < Postmany::Ports::Sleeper
  getter calls = [] of Int32

  def sleep(seconds : Int32) : Nil
    @calls << seconds
  end
end

class FakeOutput < Postmany::Ports::Output
  getter processed = [] of String
  getter errors = [] of String
  getter progresses = [] of String

  def file_processed(filename : String, silent : Bool) : Nil
    return if silent
    @processed << filename
  end

  def error(message : String) : Nil
    @errors << message
  end

  def progress(message : String) : Nil
    @progresses << message
  end
end

class FakeFilenameSource < Postmany::Ports::FilenameSource
  @filenames : Array(String)

  def initialize(filenames : Array(String))
    @filenames = filenames.dup
  end

  def next_filename : String?
    @filenames.shift?
  end
end

class InlineWorkerPool < Postmany::Ports::WorkerPool
  def run(worker_count : Int32,
          source : Postmany::Ports::FilenameSource,
          process : Proc(String, Postmany::Domain::Outcome),
          &on_outcome : Postmany::Domain::Outcome -> Nil) : Nil
    while filename = source.next_filename
      on_outcome.call(process.call(filename))
    end
  end
end

class FakeClock < Postmany::Ports::Clock
  @times : Array(Time)
  @fallback : Time

  def initialize(times : Array(Time))
    @times = times.dup
    @fallback = @times.last? || Time.utc
  end

  def now : Time
    @times.shift? || @fallback
  end
end
