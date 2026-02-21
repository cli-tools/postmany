![crystal workflow](https://github.com/cli-tools/postmany/actions/workflows/ci.yml/badge.svg)

# Postmany

Postmany reads filenames from `stdin` and transfers file content to/from an HTTP(S) endpoint.

It is designed for event-driven pipelines where a list of files is produced by one tool and streamed to another system.

## Features

- Stream filenames from `stdin`
- Upload with `POST` or `PUT`
- Download with `GET`
- Multiple worker fibers (`-w`) for concurrent transfers
- Static request headers (`-H`) for APIs like Azure Blob

## Installation

### Build from source

```sh
shards install
shards --production build --release --static
```

The compiled binary is written to `bin/postmany`.

### Docker development image

Use `compose.yml` with `crystallang/crystal:1.19.1-alpine`:

```sh
docker compose run --rm dev shards install
docker compose run --rm dev crystal spec
```

## Usage

### POST upload

```sh
URL="https://example.test/webhook"
find files -name '*.json' | postmany "$URL"
```

### PUT upload (Azure Blob style)

```sh
SAS="?sv=2020-10-02&..."
STORAGE_ACCOUNT="mystorageaccount"
CONTAINER="mycontainer"
find images -name '*.png' | \
  postmany -X PUT -H x-ms-blob-type:BlockBlob \
  "https://${STORAGE_ACCOUNT}.blob.core.windows.net/${CONTAINER}${SAS}"
```

### GET download

```sh
printf "docs/a.json\ndocs/b.json\n" | postmany -X GET "https://example.test/files"
```

## CLI Reference

| Option | Description |
|---|---|
| `-w`, `--workers=WORKERS` | Number of workers (default: `1`, minimum: `1`) |
| `-s`, `--silent` | Disable per-file stdout output |
| `--no-progress` | Disable progress messages |
| `-X`, `--request=METHOD` | HTTP method: `POST`, `PUT`, `GET` (default: `POST`) |
| `-H`, `--header=HEADER` | Static HTTP header (`key:value`) |
| `-h`, `--help` | Show help |
| `--version` | Show version |

Positional argument:

- `ENDPOINT` (required): target URL.

## Engineering Docs

Contributor workflows, architecture, and CI/CD details live in `CONTRIBUTING.md`.

## License

UNLICENSE.
