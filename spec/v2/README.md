# Operations V2 Test Suite

This directory contains the complete test suite for Operations V2, organized as a **compatibility suite** using RSpec shared examples.

## Directory Structure

```
spec/v2/
├── README.md                          # This file
├── COMPATIBILITY_TESTING.md           # Complete guide to compatibility testing
├── v2_spec_helper.rb                  # RSpec configuration and custom matchers
├── compatibility_spec.rb              # Main compatibility suite (Memory + Inline)
├── shared_examples/                   # Reusable compatibility tests
│   ├── task_dsl_examples.rb          # All DSL features (actions, decisions, etc.)
│   ├── storage_adapter_examples.rb   # Storage adapter contract tests
│   └── executor_adapter_examples.rb  # Executor adapter contract tests
└── archive/                           # Old individual specs (reference only)
    ├── README.md
    ├── single_action_spec.rb
    ├── conditional_action_spec.rb
    ├── sub_task_spec.rb
    ├── testing_spec.rb
    └── waiting_and_interactions_spec.rb
```

## Running Tests

### Run the full compatibility suite:
```bash
bundle exec rspec spec/v2/compatibility_spec.rb
```

### Run all V2 tests:
```bash
bundle exec rspec spec/v2/
```

### Run specific shared examples:
```bash
# Just DSL tests
bundle exec rspec spec/v2/compatibility_spec.rb -e "Task DSL"

# Just storage tests
bundle exec rspec spec/v2/compatibility_spec.rb -e "Storage Adapter"

# Just executor tests
bundle exec rspec spec/v2/compatibility_spec.rb -e "Executor Adapter"
```

## What Gets Tested

### Task DSL Features
- ✅ Actions with attributes and validations
- ✅ Decisions with `if_true`/`if_false` branching
- ✅ Testing individual states with `.test` method
- ✅ Sub-task creation and tracking
- ✅ Wait handlers with `wait_until`
- ✅ User interactions
- ✅ Model serialization (`has_model`, `has_models`)
- ✅ State transitions and status tracking
- ✅ Timeouts and wake scheduling

### Storage Adapter Contract
- ✅ Saving and updating tasks
- ✅ Finding tasks by ID
- ✅ Finding sleeping tasks ready to wake
- ✅ Finding sub-tasks by parent
- ✅ Deleting old tasks
- ✅ Model serialization/deserialization
- ✅ Task class restoration

### Executor Adapter Contract
- ✅ Immediate execution with `#call`
- ✅ Background execution with `#later`
- ✅ Waking sleeping tasks with `#wake`
- ✅ Exception handling and task failure

## For Adapter Developers

If you're building a storage or executor adapter, see:
- **[COMPATIBILITY_TESTING.md](COMPATIBILITY_TESTING.md)** - Complete guide
- **[../../../adapters/activerecord/spec/](../../../adapters/activerecord/spec/)** - Example adapter tests

### Quick Start

1. Add development dependency in your gemspec:
   ```ruby
   spec.add_development_dependency "standard_procedure_operations", "~> 2.0"
   ```

2. Create `spec/spec_helper.rb`:
   ```ruby
   require "operations/v2"
   require "your/adapter"

   # Load shared examples
   v2_path = Gem::Specification.find_by_name("standard_procedure_operations").gem_dir
   Dir["#{v2_path}/spec/v2/shared_examples/**/*.rb"].each { |f| require f }
   ```

3. Create `spec/compatibility_spec.rb`:
   ```ruby
   RSpec.describe "Your Adapter Compatibility" do
     let(:storage) { Your::Adapter.new }
     let(:executor) { Operations::V2::Adapters::Executor::Inline.new }

     include_examples "Operations V2 Task DSL"
     include_examples "Operations V2 Storage Adapter"
     include_examples "Operations V2 Executor Adapter"
   end
   ```

4. Run tests: `bundle exec rspec`

## Custom Matchers

The suite provides these custom RSpec matchers:

```ruby
expect(task).to be_completed
expect(task).to be_failed
expect(task).to be_active
expect(task).to be_waiting
expect(task).to be_in("state_name")
```

## Philosophy

The V2 test suite follows these principles:

1. **Tests ARE Specifications** - Shared examples define the contract
2. **Adapters Must Conform** - Any adapter passing the suite is guaranteed compatible
3. **DRY Testing** - Write tests once, run everywhere
4. **Version Safety** - Adapter tests fail if incompatible with new gem versions
5. **Swap Freely** - Users can change adapters without changing task code

## Migration from V1

V2 maintains **100% DSL compatibility** with V1. All V1 tasks should work unchanged in V2 (just swap the parent class to `Operations::V2::Task`).

The shared examples verify this compatibility by testing all V1 DSL features against V2 implementations.

## Contributing

When adding new DSL features to V2:

1. Implement feature in `lib/operations/v2/`
2. Add tests to appropriate shared examples file
3. Run compatibility suite: `bundle exec rspec spec/v2/`
4. All adapters automatically test against new features

When fixing bugs:

1. Add failing test to shared examples
2. Fix bug in implementation
3. Verify all adapters still pass

## Questions?

See [COMPATIBILITY_TESTING.md](COMPATIBILITY_TESTING.md) for comprehensive documentation.
