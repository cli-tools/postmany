![crystal workflow](https://github.com/cli-tools/postmany/actions/workflows/crystal.yml/badge.svg)

# Postmany

Postmany reads filenames from stdin and posts the content of the files provided
to a HTTP or HTTPS endpoint.

Useful for Event driven or asynchronous API data flows.

## Installation

Build with
```
shards build --production --release --static
```
using the Docker image `crystallang/crystal:alpine`.

## Usage

Give it a list of files and pipe it through `postmany`:

```
$ URL=http://webhook.site/123-123-123-123
$ find files -name data.json|head -n1|postmany "$URL"
```

Or, upload a bunch of files to Azure Blob storage:

```
$ SAS="?sv=2020-10-02&st=2022-03-20T22%3A09%3A30Z&se=2022-03-21T22%3A09%3A30Z&sr=c&sp=racwdxlt&sig=zdbnXR4qZN%2BkPd6pW5qvjhTaqp927nM2Y0Of0qQC8xU%3D"
$ STORAGE_ACCOUNT=mystorageaccount
$ CONTAINER=mycontainer
$ find images -name '*.png' | postmany -XPUT -H x-ms-blob-type:BlockBlob "https://${STORAGE_ACCOUNT}.blob.core.windows.net/${CONTAINER}${SAS}"
```

See https://docs.microsoft.com/en-us/rest/api/storageservices/put-blob for additional details on Azure Blob storage.

## Contributing

This is still ALPHA version software.

It needs some additional testing, and actual unit tests, before it should be
put into a production context.  It is already being used for test, and
integration test workflows.

1. Fork it (<https://github.com/cli-tools/postmany/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [CLI tools community](https://github.com/cli-tools) - creator and maintainer
