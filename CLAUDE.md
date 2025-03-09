# Ruby Operations Codebase Guidelines

## Build/Test Commands
```bash
# Run all tests
bundle exec rake spec

# Run a single test file
bundle exec rspec spec/path/to/file_spec.rb

# Run a specific test by line number
bundle exec rspec spec/path/to/file_spec.rb:LINE_NUMBER

# Run linter
bundle exec standardrb

# Fix linting issues
bundle exec standardrb --fix

# Start Guard for continuous testing
bundle exec guard
```

## Code Style Guidelines
- Uses Standard Ruby (standardrb) for code formatting
- Class naming: PascalCase, method naming: snake_case
- Task pattern: Inherit from Operations::Task
- Define task workflows with states (decisions, actions, results)
- Specify inputs with `inputs` and optional inputs with `optional`
- Start tasks with `starts_with :state_name`
- Use `go_to`, `fail_with` for state transitions
- Use `status_message` for tracking progress
- Testing with RSpec - use `.handling` method and custom matchers
- File structure: models in app/models/operations/, jobs in app/jobs/operations/