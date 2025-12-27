# operations-async

Async gem executor adapter for [Operations](https://github.com/standard-procedure/operations).

## Installation

```ruby
gem 'operations-async', '~> 2.0'
```

## Usage

```ruby
require 'operations/adapters/executor/async'

Operations::V2.configure do |config|
  config.executor = Operations::Adapters::Executor::Async.new
end
```

## Requirements

- standard_procedure_operations ~> 2.0
- async ~> 2.0

## Documentation

See main [Operations documentation](https://github.com/standard-procedure/operations) for details.

## License

LGPL
