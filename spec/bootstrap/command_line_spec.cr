require "../spec_helper"

describe Postmany::Bootstrap::CommandLine do
  it "parses workers, method, flags, headers, and endpoint" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    context = Postmany::Bootstrap::CommandLine.new.parse(
      ["-w", "4", "-XPUT", "-s", "--no-progress", "-H", "x-ms-blob-type:BlockBlob", "https://example.test/container?sig=1"],
      stdout,
      stderr
    )

    context.workers.should eq(4)
    context.method.should eq(Postmany::Domain::TransferMethod::PUT)
    context.silent.should be_true
    context.progress.should be_false
    context.static_headers["x-ms-blob-type"].should eq("BlockBlob")
    context.endpoint.uri.to_s.should eq("https://example.test/container?sig=1")
  end

  it "raises exit request when URL is missing" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    expect_raises(Postmany::Bootstrap::ExitRequested) do
      Postmany::Bootstrap::CommandLine.new.parse(["-X", "POST"], stdout, stderr)
    end
  end

  it "raises exit request for invalid method" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    error = expect_raises(Postmany::Bootstrap::ExitRequested) do
      Postmany::Bootstrap::CommandLine.new.parse(["-X", "PATCH", "https://example.test"], stdout, stderr)
    end

    error.code.should eq(1)
    error.message.should eq("Error: MODE must be either POST, PUT or GET")
  end

  it "raises version exit request" do
    stdout = IO::Memory.new
    stderr = IO::Memory.new

    error = expect_raises(Postmany::Bootstrap::ExitRequested) do
      Postmany::Bootstrap::CommandLine.new.parse(["--version"], stdout, stderr)
    end

    error.code.should eq(0)
    error.target.should eq(stdout)
    error.message.should eq("Postmany #{Postmany::VERSION}")
  end
end
