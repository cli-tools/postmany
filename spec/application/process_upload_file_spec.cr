require "../spec_helper"

describe Postmany::Application::ProcessUploadFile do
  it "uploads POST file content and marks success" do
    filesystem = FakeFilesystem.new({"data.json" => "{\"a\":1}"})
    mime = FakeMimeResolver.new({"data.json" => "application/json"})
    http = FakeHttpTransport.new([
      Postmany::Ports::HttpResponse.new(201),
    ])
    sleeper = FakeSleeper.new
    output = FakeOutput.new

    endpoint = Postmany::Domain::Endpoint.new(URI.parse("https://example.test/api?token=abc"))
    context = Postmany::Domain::TransferContext.new(
      endpoint,
      Postmany::Domain::TransferMethod::POST,
      1,
      false,
      true,
      {"x-static" => "1"}
    )

    use_case = Postmany::Application::ProcessUploadFile.new(filesystem, mime, http, sleeper, output)
    outcome = use_case.call("data.json", context)

    outcome.should eq(Postmany::Domain::Outcome::Ok)
    output.processed.should eq(["data.json"])
    sleeper.calls.should be_empty

    request = http.requests[0]
    request.method.should eq(Postmany::Domain::TransferMethod::POST)
    request.path.should eq("/api")
    request.query.should eq("token=abc")
    request.body.should eq("{\"a\":1}")
    request.headers["x-static"].should eq("1")
    request.headers["Content-Type"].should eq("application/json")
  end

  it "uploads PUT to path with trailing slash and filename" do
    filesystem = FakeFilesystem.new({"img.png" => "PNG"})
    mime = FakeMimeResolver.new({"img.png" => "image/png"})
    http = FakeHttpTransport.new([
      Postmany::Ports::HttpResponse.new(200),
    ])
    sleeper = FakeSleeper.new
    output = FakeOutput.new

    endpoint = Postmany::Domain::Endpoint.new(URI.parse("https://example.test/container"))
    context = Postmany::Domain::TransferContext.new(
      endpoint,
      Postmany::Domain::TransferMethod::PUT,
      1,
      false,
      true,
      Hash(String, String).new
    )

    use_case = Postmany::Application::ProcessUploadFile.new(filesystem, mime, http, sleeper, output)
    outcome = use_case.call("img.png", context)

    outcome.should eq(Postmany::Domain::Outcome::Ok)
    http.requests[0].path.should eq("/container/img.png")
  end

  it "skips when file is missing" do
    filesystem = FakeFilesystem.new
    mime = FakeMimeResolver.new
    http = FakeHttpTransport.new
    sleeper = FakeSleeper.new
    output = FakeOutput.new

    endpoint = Postmany::Domain::Endpoint.new(URI.parse("https://example.test/in"))
    context = Postmany::Domain::TransferContext.new(
      endpoint,
      Postmany::Domain::TransferMethod::POST,
      1,
      false,
      true,
      Hash(String, String).new
    )

    use_case = Postmany::Application::ProcessUploadFile.new(filesystem, mime, http, sleeper, output)
    outcome = use_case.call("missing.txt", context)

    outcome.should eq(Postmany::Domain::Outcome::Skipped)
    output.errors.should eq(["missing.txt: file not found"])
    http.requests.should be_empty
  end

  it "retries once on non-success and then succeeds" do
    filesystem = FakeFilesystem.new({"payload.bin" => "abc"})
    mime = FakeMimeResolver.new
    http = FakeHttpTransport.new([
      Postmany::Ports::HttpResponse.new(500),
      Postmany::Ports::HttpResponse.new(200),
    ])
    sleeper = FakeSleeper.new
    output = FakeOutput.new

    endpoint = Postmany::Domain::Endpoint.new(URI.parse("https://example.test/ingest"))
    context = Postmany::Domain::TransferContext.new(
      endpoint,
      Postmany::Domain::TransferMethod::POST,
      1,
      false,
      true,
      Hash(String, String).new
    )

    use_case = Postmany::Application::ProcessUploadFile.new(filesystem, mime, http, sleeper, output)
    outcome = use_case.call("payload.bin", context)

    outcome.should eq(Postmany::Domain::Outcome::Ok)
    sleeper.calls.should eq([1])
    output.errors.should eq(["payload.bin: HTTP POST error 500"])
    output.processed.should eq(["payload.bin"])
  end
end
