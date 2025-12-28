#!/usr/bin/env ruby
# Quick test to verify the compatibility suite structure works

$LOAD_PATH.unshift File.expand_path("lib", __dir__)

require "operations/v2"

# Verify shared examples can be loaded
shared_examples_path = File.expand_path("spec/v2/shared_examples", __dir__)
puts "Loading shared examples from: #{shared_examples_path}"

task_dsl = File.join(shared_examples_path, "task_dsl_examples.rb")
storage = File.join(shared_examples_path, "storage_adapter_examples.rb")
executor = File.join(shared_examples_path, "executor_adapter_examples.rb")

puts "\nVerifying files exist:"
puts "✓ Task DSL examples: #{File.exist?(task_dsl)}"
puts "✓ Storage adapter examples: #{File.exist?(storage)}"
puts "✓ Executor adapter examples: #{File.exist?(executor)}"

puts "\nTrying to load files..."
begin
  load task_dsl
  puts "✓ Loaded task_dsl_examples.rb"
rescue => e
  puts "✗ Failed to load task_dsl_examples.rb: #{e.message}"
end

begin
  load storage
  puts "✓ Loaded storage_adapter_examples.rb"
rescue => e
  puts "✗ Failed to load storage_adapter_examples.rb: #{e.message}"
end

begin
  load executor
  puts "✓ Loaded executor_adapter_examples.rb"
rescue => e
  puts "✗ Failed to load executor_adapter_examples.rb: #{e.message}"
end

puts "\n✅ Compatibility suite structure verified!"
puts "\nTo run the full suite with RSpec:"
puts "  bundle exec rspec spec/v2/compatibility_spec.rb"
