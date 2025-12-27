# operations-redis

Redis storage adapter for [Operations](https://github.com/standard-procedure/operations).

## Installation

```ruby
gem 'operations-redis', '~> 2.0'
```

## Usage

```ruby
require 'operations/adapters/storage/redis'

Operations::V2.configure do |config|
  config.storage = Operations::Adapters::Storage::Redis.new(url: ENV['REDIS_URL'])
end
```

## Requirements

- standard_procedure_operations ~> 2.0
- redis >= 5.0

## Documentation

See main [Operations documentation](https://github.com/standard-procedure/operations) for details.

## License

LGPL
