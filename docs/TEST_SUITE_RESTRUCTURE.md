# V2 Test Suite Restructure - Compatibility Suite

## Summary

The V2 test suite has been restructured from individual example specs into a **compatibility suite** using RSpec shared examples. This enables adapter gems to verify full V2 compatibility by including the same shared examples used by the main gem.

## What Changed

### Before (Individual Specs)
```
spec/v2/examples/
├── single_action_spec.rb
├── conditional_action_spec.rb
├── sub_task_spec.rb
├── testing_spec.rb
└── waiting_and_interactions_spec.rb
```

Each spec tested features in isolation. Adapter gems would need to duplicate these tests or trust they were compatible.

### After (Compatibility Suite)
```
spec/v2/
├── shared_examples/
│   ├── task_dsl_examples.rb          # All DSL features
│   ├── storage_adapter_examples.rb   # Storage contract
│   └── executor_adapter_examples.rb  # Executor contract
├── compatibility_spec.rb              # Main gem tests
└── COMPATIBILITY_TESTING.md           # Documentation
```

Shared examples define the reference behavior. Any storage/executor combination can include these examples to verify compatibility.

## Benefits

### 1. **Portable Specifications**
Tests are the specification. Adapter gems use the same tests, guaranteeing identical behavior.

### 2. **DRY Testing**
Write tests once in the main gem, run them in every adapter gem. No duplication.

### 3. **Clear Contracts**
Shared examples explicitly define what storage and executor adapters must implement:

**Storage Adapter Contract:**
- `save(task)` - Persist and assign ID
- `find(id)` - Retrieve by ID
- `sleeping_tasks(class)` - Find tasks ready to wake
- `sub_tasks_of(task)` - Find child tasks
- `delete_old(class, before:)` - Clean up
- Model serialization for `has_model`/`has_models`

**Executor Adapter Contract:**
- `call(task)` - Execute immediately
- `later(task)` - Queue for background
- `wake(task)` - Resume sleeping task

**Task DSL Coverage:**
- Actions, decisions, wait handlers
- Sub-tasks, interactions, timeouts
- State transitions, validations
- Model serialization

### 4. **Version Safety**
When the main gem is updated:
- New DSL features → New shared example tests
- Adapter gems `bundle update` → Run new tests automatically
- Tests fail → Adapter needs updating
- Tests pass → Adapter is compatible

### 5. **Easy Adapter Development**
Creating a new adapter is straightforward:

```ruby
# 1. Implement the adapter
class MyStorage < Operations::V2::Adapters::Storage::Base
  def save(task); ...; end
  def find(id); ...; end
  # ... implement full contract
end

# 2. Write compatibility spec
RSpec.describe "MyStorage Compatibility" do
  let(:storage) { MyStorage.new }
  let(:executor) { Operations::V2::Adapters::Executor::Inline.new }

  # 3. Include shared examples
  include_examples "Operations V2 Task DSL"
  include_examples "Operations V2 Storage Adapter"
  include_examples "Operations V2 Executor Adapter"
end

# 4. Run tests - if they pass, you're done!
```

## Usage

### In the Main Gem

```bash
# Run full compatibility suite
bundle exec rspec spec/v2/compatibility_spec.rb

# Run specific sections
bundle exec rspec spec/v2/compatibility_spec.rb -e "Task DSL"
bundle exec rspec spec/v2/compatibility_spec.rb -e "Storage Adapter"
```

### In Adapter Gems

```ruby
# spec/spec_helper.rb
require "operations/v2"

# Load shared examples from the main gem
gem_path = Gem::Specification.find_by_name("standard_procedure_operations").gem_dir
Dir["#{gem_path}/spec/v2/shared_examples/**/*.rb"].each { |f| require f }

# spec/compatibility_spec.rb
RSpec.describe "Adapter Compatibility" do
  let(:storage) { YourAdapter.new }
  let(:executor) { Operations::V2::Adapters::Executor::Inline.new }

  include_examples "Operations V2 Task DSL"
  include_examples "Operations V2 Storage Adapter"
  include_examples "Operations V2 Executor Adapter"
end
```

## Implementation Details

### Shared Examples Distribution

The shared examples are included in the published gem:

```ruby
# operations.gemspec
spec.files = Dir[
  "{app,config,db,lib}/**/*",
  "spec/v2/shared_examples/**/*",  # ← Shared examples included
  "LICENSE", "Rakefile", "README.md"
]
```

Adapter gems add a development dependency:

```ruby
# operations-activerecord.gemspec
spec.add_development_dependency "standard_procedure_operations", "~> 2.0"
```

This ensures adapter tests always run against the correct version of shared examples.

### Test Coverage

The shared examples provide comprehensive coverage:

**Task DSL Examples** (9 tests):
- ✅ Actions with attributes and validations
- ✅ Decisions with boolean conditions
- ✅ Testing individual states (.test method)
- ✅ Sub-task creation and tracking
- ✅ Wait handlers and interactions

**Storage Adapter Examples** (11 tests):
- ✅ Save/update tasks
- ✅ Find by ID
- ✅ Find sleeping tasks
- ✅ Find sub-tasks
- ✅ Delete old tasks
- ✅ Model serialization

**Executor Adapter Examples** (4 tests):
- ✅ Immediate execution
- ✅ Background execution
- ✅ Wake sleeping tasks
- ✅ Exception handling

**Total: 24 tests** covering all V2 features

### Backward Compatibility

All V1 DSL features are tested to ensure 100% backward compatibility:
- V1 tasks work unchanged in V2 (just change parent class)
- Same DSL methods and behavior
- Same state machine semantics

## Migration Path

The old individual specs were moved to `spec/v2/archive/` for reference. They are not run as part of the suite but are kept to:
- Document the evolution of the test suite
- Provide examples of individual features
- Help with migration to shared examples

## Future Expansion

Adding new adapters to the mono-repo:

1. **Create adapter gem structure**
   ```bash
   adapters/redis/
   ├── lib/operations/adapters/storage/redis.rb
   ├── spec/
   │   ├── spec_helper.rb
   │   └── redis_compatibility_spec.rb
   └── operations-redis.gemspec
   ```

2. **Write compatibility spec** (include shared examples)

3. **Run tests** - All 24+ compatibility tests run automatically

4. **Add adapter-specific tests** as needed

## Documentation

- **[spec/v2/README.md](../spec/v2/README.md)** - Test suite overview
- **[spec/v2/COMPATIBILITY_TESTING.md](../spec/v2/COMPATIBILITY_TESTING.md)** - Complete guide
- **[adapters/activerecord/spec/](../adapters/activerecord/spec/)** - Example implementation

## Philosophy

> "Tests are specifications. Shared examples are portable specifications."

The compatibility suite embodies the **Adapter Pattern**:
1. Define an interface (via shared examples)
2. Test against the interface (in main gem)
3. Verify implementations (in adapter gems)
4. Swap freely (users change config, not code)

This ensures the specification (tests) and implementations (adapters) stay synchronized across the entire ecosystem.

## Credits

This restructure was inspired by:
- RSpec's own adapter testing patterns
- ActiveRecord's database adapter test suite
- The principle that "the tests ARE the documentation"
