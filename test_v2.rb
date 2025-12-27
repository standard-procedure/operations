#!/usr/bin/env ruby

require_relative "lib/operations/v2"

# Test class
class GeneratesGreeting < Operations::V2::Task
  has_attribute :name, :string
  validates :name, presence: true
  has_attribute :salutation, :string, default: "Hello"
  validates :salutation, presence: true
  has_attribute :greeting, :string

  action :start do
    self.greeting = "#{salutation} #{name}!"
  end
  go_to :done

  result :done
end

puts "Testing V2 Operations..."
puts

# Test 1: Basic action flow
puts "Test 1: Basic action flow"
task = GeneratesGreeting.call(name: "World")
puts "  Status: #{task.status}"
puts "  State: #{task.current_state}"
puts "  Greeting: #{task.greeting}"
puts "  ✓ PASS" if task.completed? && task.greeting == "Hello World!"
puts

# Test 2: Custom salutation
puts "Test 2: Custom salutation"
task2 = GeneratesGreeting.call(salutation: "Heyup", name: "World")
puts "  Status: #{task2.status}"
puts "  Greeting: #{task2.greeting}"
puts "  ✓ PASS" if task2.completed? && task2.greeting == "Heyup World!"
puts

# Test 3: Validation
puts "Test 3: Validation"
begin
  task3 = GeneratesGreeting.call(name: "")
  puts "  ✗ FAIL - should have raised ValidationError"
rescue Operations::V2::ValidationError => e
  puts "  Caught expected error: #{e.message}"
  puts "  ✓ PASS"
end
puts

# Test 4: Serialization
puts "Test 4: Serialization"
task4 = GeneratesGreeting.call(name: "World")
serialized = task4.to_h
puts "  Serialized: #{serialized.inspect}"
restored = GeneratesGreeting.restore_from(serialized)
puts "  Restored greeting: #{restored.greeting}"
puts "  ✓ PASS" if restored.greeting == task4.greeting
puts

# Test 5: Storage
puts "Test 5: Storage (find task)"
task5 = GeneratesGreeting.call(name: "Storage Test")
found = GeneratesGreeting.find(task5.id)
puts "  Found task: #{found.id}"
puts "  Greeting: #{found.greeting}"
puts "  ✓ PASS" if found && found.greeting == "Hello Storage Test!"
puts

puts "All basic tests completed!"
