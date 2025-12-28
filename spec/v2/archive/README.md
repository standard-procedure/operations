# Archived V2 Specs

These spec files have been **archived** and are no longer part of the active test suite.

## What Happened

These individual example specs were consolidated into **shared examples** for compatibility testing. The active test suite now uses:

- `spec/v2/shared_examples/task_dsl_examples.rb` - All DSL features
- `spec/v2/shared_examples/storage_adapter_examples.rb` - Storage adapter contract
- `spec/v2/shared_examples/executor_adapter_examples.rb` - Executor adapter contract
- `spec/v2/compatibility_spec.rb` - Main compatibility suite

## Why Archive Instead of Delete?

These files are kept for reference purposes:

1. **Historical Record** - Shows the evolution of the test suite
2. **Migration Guide** - Helps understand how tests were reorganized
3. **Examples** - Demonstrates individual DSL features in isolation

## Running the Current Test Suite

Instead of running these archived specs, use the compatibility suite:

```bash
# Run full compatibility suite
bundle exec rspec spec/v2/compatibility_spec.rb

# Or run all V2 specs
bundle exec rspec spec/v2/
```

## See Also

- `spec/v2/COMPATIBILITY_TESTING.md` - Complete guide to the compatibility suite
- `spec/v2/shared_examples/` - Reusable compatibility tests
- `adapters/*/spec/` - How adapter gems use the shared examples
