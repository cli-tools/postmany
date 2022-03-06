# postmany

The PostMany tool reads filenames from stdin and posts the content of
the files provided to a HTTP or HTTPS endpoint.

Useful for Event driven or asyncronous API data flows.

## Installation

Build with `shards build --static --production` using
the Docker image `crystallang/crystal:alpine`.

## Usage

Give it a list of files and pipe it through `postmany`:

```
$ URL=http://webhook.site/123-123-123-123
$ find files -name data.json|head -n1|postmany "$URL"
```

## Contributing

This is still ALPHA version software.

It needs some additional testing, and actual unit tests,
before it should be put into a production context.

1. Fork it (<https://github.com/cli-tools/postmany/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [CLI tools community](https://github.com/cli-tools) - creator and maintainer
