require "http/client"
require "uri"
require "mime"
require "option_parser"
require "colorize"
require "set"

require "./postmany/version"

module Postmany::Domain
end

module Postmany::Ports
end

module Postmany::Application
end

module Postmany::Adapters
end

module Postmany::Bootstrap
end

require "./postmany/domain/transfer_method"
require "./postmany/domain/outcome"
require "./postmany/domain/endpoint"
require "./postmany/domain/transfer_context"
require "./postmany/domain/batch_result"

require "./postmany/ports/filesystem"
require "./postmany/ports/http_transport"
require "./postmany/ports/mime_resolver"
require "./postmany/ports/sleeper"
require "./postmany/ports/output"
require "./postmany/ports/filename_source"
require "./postmany/ports/file_processor"
require "./postmany/ports/worker_pool"
require "./postmany/ports/clock"

require "./postmany/application/process_upload_file"
require "./postmany/application/process_download_file"
require "./postmany/application/process_file"
require "./postmany/application/run_transfer_batch"

require "./postmany/adapters/local_filesystem"
require "./postmany/adapters/crystal_http_transport"
require "./postmany/adapters/filename_mime_resolver"
require "./postmany/adapters/kernel_sleeper"
require "./postmany/adapters/system_clock"
require "./postmany/adapters/terminal_output"
require "./postmany/adapters/io_filename_source"
require "./postmany/adapters/fiber_worker_pool"

require "./postmany/bootstrap/command_line"
require "./postmany/bootstrap/runner"
