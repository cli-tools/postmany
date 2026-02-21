# Contributing to Postmany

## Architecture

Postmany follows a hexagonal (ports and adapters) architecture.

### Layers

- `src/postmany/domain`: core types and policies (`TransferMethod`, `Endpoint`, `TransferContext`, `BatchResult`, `Outcome`)
- `src/postmany/application`: use cases (`ProcessUploadFile`, `ProcessDownloadFile`, `ProcessFile`, `RunTransferBatch`)
- `src/postmany/ports`: interfaces for side effects (HTTP, filesystem, output, time, worker pool, filename source, MIME resolver)
- `src/postmany/adapters`: concrete implementations (Crystal HTTP client, local filesystem, terminal output, fiber worker pool, etc.)
- `src/postmany/bootstrap`: CLI parsing and dependency wiring (`CommandLine`, `Runner`)

CLI entrypoint is `src/postmany_cli.cr` and only delegates to `Postmany::Bootstrap::Runner`.

## Dependency Injection and Test Doubles

Application use cases receive dependencies through constructor injection.

Examples:

- `ProcessUploadFile` depends on filesystem, MIME resolver, HTTP transport, sleeper, and output ports
- `RunTransferBatch` depends on worker pool, file processor, output, and clock ports

Tests use hand-written doubles in `spec/support/fakes.cr` instead of a mocking framework.

## Testing

Run all specs:

```sh
crystal spec
```

The suite covers:

- upload/download behavior
- retry and skip semantics
- batch counting/progress reporting
- CLI parsing and error/version flows

## Code Quality

Use read-only format validation before submitting:

```sh
crystal tool format --check src spec
```

If formatting changes are needed:

```sh
crystal tool format src spec
```

## Pre-Submit Checklist

Before opening a PR:

```sh
shards install
crystal tool format --check src spec
crystal spec
shards --production build --release --static
```

Minimum bar:

- Formatting is clean
- Specs pass
- Release build succeeds

## CI/CD

GitHub Actions workflow: `.github/workflows/ci.yml`

Jobs:

- `quality`: install deps, format check, specs (Crystal `1.19.1`)
- `build`: static release build + artifact upload
- `release`: on tag `v*.*.*`, publish artifact to GitHub Releases

## Project Structure

```text
.
├── src/
│   ├── postmany_cli.cr
│   └── postmany/
│       ├── domain/
│       ├── application/
│       ├── ports/
│       ├── adapters/
│       └── bootstrap/
├── spec/
│   ├── application/
│   ├── bootstrap/
│   └── support/
├── compose.yml
├── shard.yml
└── .github/workflows/ci.yml
```
