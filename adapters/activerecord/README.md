# operations-activerecord

ActiveRecord storage adapter for [Operations](https://github.com/standard-procedure/operations).

## Installation

```ruby
gem 'operations-activerecord', '~> 2.0'
```

## Usage

```ruby
require 'operations/adapters/storage/active_record'

Operations::V2.configure do |config|
  config.storage = Operations::Adapters::Storage::ActiveRecord.new
end
```

## Requirements

- standard_procedure_operations ~> 2.0
- activerecord >= 7.0

## Documentation

See main [Operations documentation](https://github.com/standard-procedure/operations) for details.

## License

LGPL
