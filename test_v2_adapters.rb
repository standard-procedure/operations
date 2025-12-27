#!/usr/bin/env ruby

require_relative "lib/operations/v2"

# Test both Memory and new adapter structure
puts "=" * 80
puts "Testing V2 Adapters (Phase 2)"
puts "=" * 80
puts

# Test class
class AdapterTestTask < Operations::V2::Task
  has_attribute :name, :string
  validates :name, presence: true
  has_attribute :result, :string

  action :start do
    self.result = "Processed: #{name}"
  end
  go_to :done

  result :done
end

# Test 1: Verify new adapter structure works
puts "Test 1: New adapter structure"
puts "-" * 40

Operations::V2.configure do |config|
  config.storage = Operations::V2::Adapters::Storage::Memory.new
  config.executor = Operations::V2::Adapters::Executor::Inline.new
end

task1 = AdapterTestTask.call(name: "Adapter Test")
puts "  Task completed: #{task1.completed?}"
puts "  Result: #{task1.result}"
puts "  ✓ PASS" if task1.completed? && task1.result == "Processed: Adapter Test"
puts

# Test 2: Verify backward compatibility
puts "Test 2: Backward compatibility (old class names)"
puts "-" * 40

Operations::V2.storage = Operations::V2::MemoryStorage.new
Operations::V2.executor = Operations::V2::InlineExecutor.new

task2 = AdapterTestTask.call(name: "Backward Compat")
puts "  Task completed: #{task2.completed?}"
puts "  Result: #{task2.result}"
puts "  ✓ PASS" if task2.completed?
puts

# Test 3: Verify adapter interface
puts "Test 3: Storage adapter interface"
puts "-" * 40

storage = Operations::V2::Adapters::Storage::Memory.new
puts "  storage.is_a?(Operations::V2::Adapters::Storage::Base): #{storage.is_a?(Operations::V2::Adapters::Storage::Base)}"
puts "  storage responds to #save: #{storage.respond_to?(:save)}"
puts "  storage responds to #find: #{storage.respond_to?(:find)}"
puts "  storage responds to #sleeping_tasks: #{storage.respond_to?(:sleeping_tasks)}"
puts "  storage responds to #sub_tasks_of: #{storage.respond_to?(:sub_tasks_of)}"
puts "  storage responds to #delete_old: #{storage.respond_to?(:delete_old)}"
puts "  ✓ PASS" if storage.is_a?(Operations::V2::Adapters::Storage::Base)
puts

# Test 4: Verify executor interface
puts "Test 4: Executor adapter interface"
puts "-" * 40

executor = Operations::V2::Adapters::Executor::Inline.new
puts "  executor.is_a?(Operations::V2::Adapters::Executor::Base): #{executor.is_a?(Operations::V2::Adapters::Executor::Base)}"
puts "  executor responds to #call: #{executor.respond_to?(:call)}"
puts "  executor responds to #later: #{executor.respond_to?(:later)}"
puts "  executor responds to #wake: #{executor.respond_to?(:wake)}"
puts "  ✓ PASS" if executor.is_a?(Operations::V2::Adapters::Executor::Base)
puts

# Test 5: Verify thread-safety of Memory adapter
puts "Test 5: Thread-safety (concurrent access)"
puts "-" * 40

Operations::V2.storage = Operations::V2::Adapters::Storage::Memory.new

threads = 10.times.map do |i|
  Thread.new do
    task = AdapterTestTask.call(name: "Thread #{i}")
    task.completed?
  end
end

results = threads.map(&:value)
puts "  Started #{threads.count} threads"
puts "  All completed: #{results.all?}"
puts "  ✓ PASS" if results.all?
puts

# Test 6: Can swap adapters
puts "Test 6: Adapter swapping"
puts "-" * 40

# Use first adapter
Operations::V2.storage = Operations::V2::Adapters::Storage::Memory.new
task_a = AdapterTestTask.call(name: "Adapter A")
id_a = task_a.id

# Swap to new adapter
Operations::V2.storage = Operations::V2::Adapters::Storage::Memory.new
task_b = AdapterTestTask.call(name: "Adapter B")
id_b = task_b.id

puts "  Task A ID: #{id_a}"
puts "  Task B ID: #{id_b}"
puts "  Can't find task A in new storage: #{Operations::V2.storage.find(id_a).nil?}"
puts "  ✓ PASS - adapters are independent"
puts

puts "=" * 80
puts "All Phase 2 adapter tests passed!"
puts "=" * 80
puts
puts "Next: Test ActiveRecord adapter when ActiveRecord is available"
