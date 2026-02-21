require "../spec_helper"

describe Postmany::Application::RunTransferBatch do
  it "counts outcomes and emits final progress for POST" do
    filesystem = FakeFilesystem.new({"a.txt" => "a"})
    mime = FakeMimeResolver.new
    http = FakeHttpTransport.new([
      Postmany::Ports::HttpResponse.new(200),
    ])
    sleeper = FakeSleeper.new
    output = FakeOutput.new

    endpoint = Postmany::Domain::Endpoint.new(URI.parse("https://example.test/inbox"))
    context = Postmany::Domain::TransferContext.new(
      endpoint,
      Postmany::Domain::TransferMethod::POST,
      2,
      false,
      true,
      Hash(String, String).new
    )

    upload = Postmany::Application::ProcessUploadFile.new(filesystem, mime, http, sleeper, output)
    download = Postmany::Application::ProcessDownloadFile.new(filesystem, http, sleeper, output)
    process_file = Postmany::Application::ProcessFile.new(upload, download)

    t0 = Time.utc
    clock = FakeClock.new([t0, t0, t0, t0])
    worker_pool = InlineWorkerPool.new
    source = FakeFilenameSource.new(["a.txt", "b.txt"])

    use_case = Postmany::Application::RunTransferBatch.new(worker_pool, process_file, output, clock)
    result = use_case.call(source, context)

    result.ok.should eq(1)
    result.skipped.should eq(1)
    result.total.should eq(2)
    output.progresses.should eq(["1 files sent; 1 skipped"])
  end

  it "uses receive wording for GET progress" do
    filesystem = FakeFilesystem.new
    http = FakeHttpTransport.new([
      Postmany::Ports::HttpResponse.new(200, "one"),
    ])
    sleeper = FakeSleeper.new
    output = FakeOutput.new

    endpoint = Postmany::Domain::Endpoint.new(URI.parse("https://example.test/files"))
    context = Postmany::Domain::TransferContext.new(
      endpoint,
      Postmany::Domain::TransferMethod::GET,
      1,
      false,
      true,
      Hash(String, String).new
    )

    upload = Postmany::Application::ProcessUploadFile.new(filesystem, FakeMimeResolver.new, http, sleeper, output)
    download = Postmany::Application::ProcessDownloadFile.new(filesystem, http, sleeper, output)
    process_file = Postmany::Application::ProcessFile.new(upload, download)

    t0 = Time.utc
    clock = FakeClock.new([t0, t0])
    worker_pool = InlineWorkerPool.new
    source = FakeFilenameSource.new(["one.txt"])

    use_case = Postmany::Application::RunTransferBatch.new(worker_pool, process_file, output, clock)
    result = use_case.call(source, context)

    result.ok.should eq(1)
    output.progresses.should eq(["1 files received; 0 skipped"])
  end
end
