# operations-activejob

ActiveJob executor adapter for [Operations](https://github.com/standard-procedure/operations).

## Installation

```ruby
gem 'operations-activejob', '~> 2.0'
```

## Usage

```ruby
require 'operations/adapters/executor/active_job'

Operations::V2.configure do |config|
  config.executor = Operations::Adapters::Executor::ActiveJob.new
end
```

## Requirements

- standard_procedure_operations ~> 2.0
- activejob >= 7.0

## Documentation

See main [Operations documentation](https://github.com/standard-procedure/operations) for details.

## License

LGPL
