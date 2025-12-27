# Operations Mono-Repo Structure

This repository uses a **mono-repo** approach to manage multiple related gems with synchronized versions.

## Repository Structure

```
standard-procedure/operations/
├── operations.gemspec              # Core gem: standard_procedure_operations
├── adapters/
│   ├── activerecord/
│   │   ├── operations-activerecord.gemspec
│   │   ├── lib/operations-activerecord/
│   │   └── spec/
│   ├── activejob/
│   │   ├── operations-activejob.gemspec
│   │   ├── lib/operations-activejob/
│   │   └── spec/
│   ├── async/
│   │   ├── operations-async.gemspec
│   │   ├── lib/operations-async/
│   │   └── spec/
│   └── redis/
│       ├── operations-redis.gemspec
│       ├── lib/operations-redis/
│       └── spec/
├── lib/
│   ├── operations/
│   │   ├── version.rb              # SINGLE SOURCE OF TRUTH for version
│   │   └── v2/                     # Core V2 implementation
│   └── operations-activerecord/    # Adapter implementations
│       └── ...
├── spec/
│   ├── v2/                         # Core specs
│   └── adapters/                   # Adapter specs
│       ├── activerecord/
│       └── ...
└── bin/
    └── release                     # Automated release script
```

## Published Gems

This repository produces **5 separate gems** published to RubyGems:

1. **standard_procedure_operations** (core) - Zero dependencies
2. **operations-activerecord** - ActiveRecord storage adapter
3. **operations-activejob** - ActiveJob executor adapter
4. **operations-async** - Async gem executor adapter
5. **operations-redis** - Redis storage adapter

## Version Management

### Synchronized Versioning

All gems share **Major.Minor** version numbers to indicate compatibility:

```ruby
# lib/operations/version.rb - SINGLE SOURCE OF TRUTH
module Operations
  VERSION = "2.1.0"
end

# All gemspecs reference this version:
spec.version = Operations::VERSION
```

### Version Policy

- **Major.Minor** versions are **synchronized** across all gems
  - Example: Core `2.1.x` works with adapters `2.1.x`
  - Breaking changes increment major version across all gems
  - New features increment minor version across all gems

- **Patch** versions can **diverge** for adapter-specific fixes
  - Example: Core `2.1.0`, ActiveRecord adapter `2.1.1` (bug fix), Async adapter `2.1.0`
  - Patch-only changes don't affect other gems

### Dependency Declarations

Adapters depend on core with `~>` major.minor constraint:

```ruby
# adapters/activerecord/operations-activerecord.gemspec
major_minor = Operations::VERSION.split('.')[0..1].join('.')
spec.add_dependency "standard_procedure_operations", "~> #{major_minor}"
# If VERSION = "2.1.0", this becomes "~> 2.1"
# Allows core 2.1.0, 2.1.1, 2.1.2, etc. but not 2.2.0
```

## Why Mono-Repo?

### Advantages

1. **Version Synchronization** - Single source of truth for version numbers
2. **Atomic Changes** - Change core interface + adapter in single PR
3. **Easier Testing** - Test adapters against unreleased core changes
4. **Better DX** - Clone once, work on everything
5. **Unified CI** - Single pipeline runs all tests
6. **Consistent Style** - Same linting/formatting across all gems

### When We Might Split

We'll consider splitting if:
- An adapter grows very large (>1000 LOC)
- An adapter has completely different release cadence
- An adapter has different maintainers/governance

For now, none of these apply.

## Development Workflow

### Making Changes

**Core changes:**
```bash
# Edit files in lib/operations/v2/
# Tests in spec/v2/
```

**Adapter changes:**
```bash
# Edit files in adapters/activerecord/lib/
# Tests in adapters/activerecord/spec/
```

**Breaking changes (major version bump):**
1. Update core code
2. Update ALL affected adapters
3. Bump version to next major (e.g., 2.0.0 → 3.0.0)
4. Single PR contains all changes
5. Release all gems together

**New features (minor version bump):**
1. Add feature to core or adapter
2. Bump minor version (e.g., 2.1.0 → 2.2.0)
3. Release affected gems

**Bug fixes (patch version bump):**
1. Fix bug in specific gem
2. Bump patch version for that gem only
3. Release only that gem

### Running Tests

```bash
# All tests
bundle exec rspec

# Core tests only
bundle exec rspec spec/v2

# Specific adapter tests
bundle exec rspec adapters/activerecord/spec
```

### Building Gems Locally

```bash
# Build core
gem build operations.gemspec

# Build adapter
cd adapters/activerecord
gem build operations-activerecord.gemspec
```

## Releasing

### Prerequisites

1. All tests passing
2. CHANGELOG updated
3. Version bumped in `lib/operations/version.rb`
4. Clean git state (all changes committed)

### Release Process

```bash
# Use automated release script
bin/release

# Follow prompts to:
# 1. Build all gems
# 2. Push to RubyGems
# 3. Tag release
# 4. Create GitHub release
```

### Manual Release (if needed)

```bash
# 1. Build all gems
gem build operations.gemspec
cd adapters/activerecord && gem build operations-activerecord.gemspec && cd ../..
cd adapters/activejob && gem build operations-activejob.gemspec && cd ../..
cd adapters/async && gem build operations-async.gemspec && cd ../..
cd adapters/redis && gem build operations-redis.gemspec && cd ../..

# 2. Push to RubyGems
gem push standard_procedure_operations-2.1.0.gem
gem push operations-activerecord-2.1.0.gem
gem push operations-activejob-2.1.0.gem
gem push operations-async-2.1.0.gem
gem push operations-redis-2.1.0.gem

# 3. Tag and push
git tag v2.1.0
git push origin v2.1.0

# 4. Create GitHub release with changelog
gh release create v2.1.0 --notes-file CHANGELOG.md
```

## User Installation

Users install only what they need:

```ruby
# Gemfile for standalone app
gem 'standard_procedure_operations', '~> 2.1'
gem 'operations-async', '~> 2.1'

# Gemfile for Rails app
gem 'standard_procedure_operations', '~> 2.1'
gem 'operations-activerecord', '~> 2.1'
gem 'operations-activejob', '~> 2.1'
```

The `~> 2.1` constraint ensures:
- Compatible with 2.1.0, 2.1.1, 2.1.2, etc.
- Not compatible with 2.2.0 (minor version bump = new features)
- Not compatible with 3.0.0 (major version bump = breaking changes)

## Questions?

- **Q: Why not separate repos?**
  A: Harder to keep versions in sync, harder to test changes across gems, more overhead.

- **Q: Why sync major.minor but not patch?**
  A: Patch fixes are often adapter-specific and don't affect compatibility.

- **Q: Can I release just one gem?**
  A: Yes, for patch releases. For major/minor, release all to keep versions in sync.

- **Q: What if an adapter isn't ready for release?**
  A: Major/minor releases wait until all adapters are ready. That's why we mono-repo!

## References

Similar successful mono-repos:
- **rom-rb** - rom, rom-sql, rom-elasticsearch
- **hanami** - hanami core + adapters
- **dry-rb ecosystem** - multiple dry-* gems
