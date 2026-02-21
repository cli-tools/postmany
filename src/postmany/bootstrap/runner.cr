class Postmany::Bootstrap::Runner
  def initialize(@command_line : Postmany::Bootstrap::CommandLine = Postmany::Bootstrap::CommandLine.new)
  end

  def run(argv : Array(String), stdin : IO = STDIN, stdout : IO = STDOUT, stderr : IO = STDERR) : Int32
    context = @command_line.parse(argv.dup, stdout, stderr)

    output = Postmany::Adapters::TerminalOutput.new(stdout, stderr)
    source = Postmany::Adapters::IOFilenameSource.new(stdin)

    http = begin
      Postmany::Adapters::CrystalHttpTransport.new(context.endpoint.uri, context.static_headers)
    rescue ex
      stderr.puts "worker 0: HTTP client could not connect to #{context.endpoint.uri}: #{ex}"
      return 2
    end

    filesystem = Postmany::Adapters::LocalFilesystem.new
    mime_resolver = Postmany::Adapters::FilenameMimeResolver.new
    sleeper = Postmany::Adapters::KernelSleeper.new
    clock = Postmany::Adapters::SystemClock.new
    worker_pool = Postmany::Adapters::FiberWorkerPool.new

    upload = Postmany::Application::ProcessUploadFile.new(filesystem, mime_resolver, http, sleeper, output)
    download = Postmany::Application::ProcessDownloadFile.new(filesystem, http, sleeper, output)
    process_file = Postmany::Application::ProcessFile.new(upload, download)
    run_batch = Postmany::Application::RunTransferBatch.new(worker_pool, process_file, output, clock)

    run_batch.call(source, context)
    0
  rescue ex : Postmany::Bootstrap::ExitRequested
    ex.target.puts(ex.message)
    ex.code
  end
end
