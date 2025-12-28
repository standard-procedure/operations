# Operations V2 Compatibility Testing

This directory contains the **compatibility test suite** for Operations V2. The suite uses RSpec shared examples to define reference behavior that all storage and executor adapters must implement.

## Architecture

The compatibility suite is organized into three sets of shared examples:

### 1. Task DSL Examples (`shared_examples/task_dsl_examples.rb`)

Tests all V2 DSL features to ensure they work correctly with any storage/executor combination:

- **Actions** - Basic state machine execution
- **Decisions** - Conditional branching with `if_true`/`if_false`
- **Testing** - The `.test` method for testing individual states
- **Sub-tasks** - Creating and tracking child tasks
- **Waiting and Interactions** - `wait_until` handlers and user interactions

### 2. Storage Adapter Examples (`shared_examples/storage_adapter_examples.rb`)

Defines the **storage adapter contract** that all storage implementations must fulfill:

- `#save(task)` - Persist tasks and assign IDs
- `#find(id)` - Retrieve tasks by ID
- `#sleeping_tasks(task_class)` - Find tasks ready to wake up
- `#sub_tasks_of(task)` - Find child tasks
- `#delete_old(task_class, before:)` - Clean up old tasks
- Model serialization - Handle `has_model` and `has_models`

### 3. Executor Adapter Examples (`shared_examples/executor_adapter_examples.rb`)

Defines the **executor adapter contract** that all execution implementations must fulfill:

- `#call(task)` - Execute task immediately
- `#later(task)` - Queue task for background execution
- `#wake(task)` - Resume a sleeping task
- Exception handling - Mark failed tasks appropriately

## Using the Compatibility Suite

### In the Main Gem

The main gem tests the reference implementation (Memory + Inline):

```ruby
# spec/v2/compatibility_spec.rb
RSpec.describe "Operations V2 Compatibility Suite" do
  describe "Memory Storage + Inline Executor" do
    let(:storage) { Operations::V2::Adapters::Storage::Memory.new }
    let(:executor) { Operations::V2::Adapters::Executor::Inline.new }

    include_examples "Operations V2 Task DSL"
    include_examples "Operations V2 Storage Adapter"
    include_examples "Operations V2 Executor Adapter"
  end
end
```

### In Adapter Gems

Adapter gems include the shared examples to verify compatibility:

```ruby
# adapters/activerecord/spec/activerecord_compatibility_spec.rb
RSpec.describe "ActiveRecord Storage Adapter Compatibility" do
  let(:storage) { Operations::Adapters::Storage::ActiveRecord.new }
  let(:executor) { Operations::V2::Adapters::Executor::Inline.new }

  before(:each) do
    Operations::TaskRecord.delete_all
    Operations::V2.configure do |config|
      config.storage = storage
      config.executor = executor
    end
  end

  # Run the full compatibility suite
  include_examples "Operations V2 Task DSL"
  include_examples "Operations V2 Storage Adapter"
  include_examples "Operations V2 Executor Adapter"

  # Add adapter-specific tests
  describe "ActiveRecord-specific features" do
    # ...
  end
end
```

### Setup for Adapter Gems

1. **Add dependency** on the main gem in your gemspec:
   ```ruby
   spec.add_development_dependency "standard_procedure_operations", "~> 2.0"
   ```

2. **Load shared examples** in your `spec_helper.rb`:
   ```ruby
   # Load shared examples from main gem
   v2_spec_path = File.expand_path("path/to/main/gem/spec/v2/shared_examples", __dir__)
   Dir["#{v2_spec_path}/**/*.rb"].each { |f| require f }
   ```

3. **Create compatibility spec** that includes the shared examples

4. **Run the suite**:
   ```bash
   bundle exec rspec
   ```

## Benefits

### For Adapter Authors

- **Clear Contract** - Shared examples document exactly what your adapter must implement
- **Comprehensive Testing** - Test all edge cases without writing them yourself
- **Regression Prevention** - Catch breaking changes immediately
- **Compatibility Guarantee** - If tests pass, your adapter works with all V2 features

### For Users

- **Confidence** - Any adapter passing the suite is guaranteed to work
- **Swappable Adapters** - Switch storage/executors without changing task code
- **Consistent Behavior** - All adapters behave identically from DSL perspective

### For Maintainers

- **DRY Tests** - Write tests once, run everywhere
- **Reference Spec** - Shared examples ARE the specification
- **Easy Updates** - Add new DSL features, update shared examples, all adapters get new tests
- **Version Compatibility** - Adapter tests fail if they're incompatible with new gem version

## Running Tests

### Main Gem
```bash
cd /path/to/operations
bundle exec rspec spec/v2/compatibility_spec.rb
```

### ActiveRecord Adapter
```bash
cd adapters/activerecord
bundle exec rspec spec/activerecord_compatibility_spec.rb
```

### All Adapters (from mono-repo root)
```bash
# Run compatibility suite for all adapters
for adapter in adapters/*/; do
  echo "Testing $adapter"
  cd "$adapter"
  bundle exec rspec spec/*_compatibility_spec.rb
  cd ../..
done
```

## Adding New DSL Features

When adding new features to V2:

1. Implement the feature in `lib/operations/v2/`
2. Add tests to the appropriate shared examples file
3. Verify main gem tests pass
4. Adapter gems automatically get new tests on next `bundle update`
5. Adapter authors fix any failing tests to maintain compatibility

## Compatibility Matrix

| Adapter | Task DSL | Storage Contract | Executor Contract | Status |
|---------|----------|------------------|-------------------|--------|
| Memory + Inline | ✅ | ✅ | ✅ | Reference |
| ActiveRecord + Inline | ✅ | ✅ | ✅ | Compatible |
| Redis + Inline | ⏳ | ⏳ | ✅ | Planned |
| Memory + ActiveJob | ✅ | ✅ | ⏳ | Planned |
| Memory + Async | ✅ | ✅ | ⏳ | Planned |

## Philosophy

> "Tests are specifications. Shared examples are portable specifications."

The compatibility suite embodies the **Adapter Pattern** principle: define an interface, test against the interface, swap implementations freely. By making tests portable via shared examples, we ensure that the specification (the tests) and the implementations (the adapters) stay in sync across the entire ecosystem.
