require "../spec_helper"

describe Postmany::Application::ProcessDownloadFile do
  it "writes downloaded content on HTTP 200" do
    filesystem = FakeFilesystem.new
    http = FakeHttpTransport.new([
      Postmany::Ports::HttpResponse.new(200, "blob"),
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

    use_case = Postmany::Application::ProcessDownloadFile.new(filesystem, http, sleeper, output)
    outcome = use_case.call("a/b.txt", context)

    outcome.should eq(Postmany::Domain::Outcome::Ok)
    filesystem.ensured_paths.should eq(["a/b.txt"])
    filesystem.writes["a/b.txt"].should eq("blob")
    output.processed.should eq(["a/b.txt"])
    sleeper.calls.should be_empty
  end

  it "skips on HTTP 404 without retry" do
    filesystem = FakeFilesystem.new
    http = FakeHttpTransport.new([
      Postmany::Ports::HttpResponse.new(404),
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

    use_case = Postmany::Application::ProcessDownloadFile.new(filesystem, http, sleeper, output)
    outcome = use_case.call("missing.txt", context)

    outcome.should eq(Postmany::Domain::Outcome::Skipped)
    output.errors.should eq(["missing.txt: HTTP GET error 404"])
    sleeper.calls.should be_empty
  end

  it "retries server errors and succeeds" do
    filesystem = FakeFilesystem.new
    http = FakeHttpTransport.new([
      Postmany::Ports::HttpResponse.new(500),
      Postmany::Ports::HttpResponse.new(200, "ok"),
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

    use_case = Postmany::Application::ProcessDownloadFile.new(filesystem, http, sleeper, output)
    outcome = use_case.call("retry.txt", context)

    outcome.should eq(Postmany::Domain::Outcome::Ok)
    sleeper.calls.should eq([1])
    output.errors.should eq(["retry.txt: HTTP GET error 500"])
  end

  it "skips when transport raises an exception" do
    filesystem = FakeFilesystem.new
    http = FakeHttpTransport.new([
      Socket::ConnectError.new("down"),
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

    use_case = Postmany::Application::ProcessDownloadFile.new(filesystem, http, sleeper, output)
    outcome = use_case.call("fail.txt", context)

    outcome.should eq(Postmany::Domain::Outcome::Skipped)
    output.errors.size.should eq(1)
    output.errors[0].starts_with?("fail.txt:").should be_true
  end
end
