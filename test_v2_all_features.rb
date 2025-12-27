#!/usr/bin/env ruby

# Comprehensive test of all V2 features ported from V1 specs
require_relative "lib/operations/v2"

puts "=" * 80
puts "Testing All V2 Features (Ported from V1)"
puts "=" * 80
puts

test_count = 0
passed_count = 0
failed_tests = []

def test(name)
  print "#{name}... "
  begin
    yield
    puts "✓ PASS"
    return true
  rescue => e
    puts "✗ FAIL"
    puts "  Error: #{e.message}"
    puts "  #{e.backtrace.first}"
    return false
  end
end

# Configure for testing
Operations::V2.storage = Operations::V2::Adapters::Storage::Memory.new
Operations::V2.executor = Operations::V2::Adapters::Executor::Inline.new

puts "Feature 1: Actions (single_action_spec)"
puts "-" * 40

class GeneratesGreetingV2 < Operations::V2::Task
  has_attribute :name, :string
  validates :name, presence: true
  has_attribute :salutation, :string, default: "Hello"
  has_attribute :greeting, :string

  action :start do
    self.greeting = "#{salutation} #{name}!"
  end
  go_to :done

  result :done
end

test_count += 1
passed_count += 1 if test("generates greeting") do
  task = GeneratesGreetingV2.call(name: "World")
  raise "Not completed" unless task.completed?
  raise "Wrong greeting: #{task.greeting}" unless task.greeting == "Hello World!"
end

test_count += 1
passed_count += 1 if test("allows salutation override") do
  task = GeneratesGreetingV2.call(salutation: "Heyup", name: "World")
  raise "Wrong greeting" unless task.greeting == "Heyup World!"
end

test_count += 1
passed_count += 1 if test("validates required fields") do
  begin
    GeneratesGreetingV2.call(name: "")
    raise "Should have raised ValidationError"
  rescue Operations::V2::ValidationError
    # Expected
  end
end

puts

puts "Feature 2: Decisions (conditional_action_spec)"
puts "-" * 40

class SaysHelloOrGoodbyeV2 < Operations::V2::Task
  has_attribute :name, :string
  validates :name, presence: true
  has_attribute :arriving, :boolean, default: true
  has_attribute :message, :string
  starts_with :coming_or_going?

  decision :coming_or_going? do
    condition { arriving? }
    if_true :say_hello
    if_false :say_goodbye
  end

  action :say_hello do
    self.message = "Hello #{name}"
  end.then :done

  action :say_goodbye do
    self.message = "Goodbye #{name}"
  end.then :done

  result :done
end

test_count += 1
passed_count += 1 if test("says hello when arriving") do
  task = SaysHelloOrGoodbyeV2.call(name: "Alice", arriving: true)
  raise "Not completed" unless task.completed?
  raise "Wrong message" unless task.message == "Hello Alice"
end

test_count += 1
passed_count += 1 if test("says goodbye when leaving") do
  task = SaysHelloOrGoodbyeV2.call(name: "Alice", arriving: false)
  raise "Not completed" unless task.completed?
  raise "Wrong message: got '#{task.message}', expected 'Goodbye Alice'" unless task.message == "Goodbye Alice"
end

puts

puts "Feature 3: Testing (.test method)"
puts "-" * 40

class WeekendCheckerV2 < Operations::V2::Task
  has_attribute :day_of_week, :string, default: "Monday"
  validates :day_of_week, presence: true
  starts_with :is_it_the_weekend?

  decision :is_it_the_weekend? do
    condition { %w[Saturday Sunday].include? day_of_week }
    if_true :weekend
    if_false :weekday
  end

  result :weekend
  result :weekday
end

test_count += 1
passed_count += 1 if test(".test method works for Saturday") do
  task = WeekendCheckerV2.test :is_it_the_weekend?, day_of_week: "Saturday"
  raise "Not in weekend state" unless task.in?(:weekend)
end

test_count += 1
passed_count += 1 if test(".test method works for Wednesday") do
  task = WeekendCheckerV2.test :is_it_the_weekend?, day_of_week: "Wednesday"
  raise "Not in weekday state" unless task.in?(:weekday)
end

puts

puts "Feature 4: Sub-tasks"
puts "-" * 40

class OtherThingTaskV2 < Operations::V2::Task
  has_attribute :number, :integer
  has_attribute :greeting, :string, default: "Hello"

  action :start do
    self.greeting = "Task #{number}: #{greeting}"
  end
  go_to :done

  result :done
end

class StartsSubTasksV2 < Operations::V2::Task
  has_attribute :counter, :integer, default: 1

  action :start do
    counter.times { |i| start OtherThingTaskV2, number: i }
  end.then :done

  result :done
end

test_count += 1
passed_count += 1 if test("starts sub-tasks") do
  parent = StartsSubTasksV2.call counter: 3
  raise "Parent not completed" unless parent.completed?
  raise "Wrong number of sub-tasks: #{parent.sub_tasks.size}" unless parent.sub_tasks.size == 3
  raise "Sub-tasks should be waiting" unless parent.sub_tasks.all?(&:waiting?)
end

puts

puts "Feature 5: Waiting and Interactions"
puts "-" * 40

class MockUser
  attr_accessor :id, :name
  @@next_id = 1
  @@users = {}

  def self.create!(attrs)
    u = new
    u.id = @@next_id
    @@next_id += 1
    u.name = attrs[:name]
    @@users[u.id] = u
    u
  end

  def self.find(id)
    @@users[id]
  end
end

class UserRegistrationV2 < Operations::V2::Task
  has_attribute :email, :string
  validates :email, presence: true
  has_attribute :name, :string
  has_model :user, "MockUser"
  starts_with :send_invitation

  action :send_invitation do
    # Mailer would go here
  end
  go_to :name_provided?

  wait_until :name_provided? do
    condition { !name.nil? && !name.empty? }
    go_to :create_user
  end

  interaction :register! do |name|
    self.name = name
  end

  action :create_user do
    self.user = MockUser.create! name: name
  end
  go_to :done

  result :done
end

test_count += 1
passed_count += 1 if test("waits for user interaction") do
  reg = UserRegistrationV2.call email: "alice@example.com"
  raise "Should be waiting" unless reg.waiting?
  raise "Should be waiting_until name_provided?" unless reg.waiting_until?("name_provided?")

  reg.register! "Bob Badger"

  raise "Should be completed" unless reg.completed?
  raise "Should have user" if reg.user.nil?
  raise "Wrong user name" unless reg.user.name == "Bob Badger"
  raise "Should be in done state" unless reg.in?("done")
end

puts

puts "=" * 80
puts "Test Results"
puts "=" * 80
puts "Total: #{test_count}"
puts "Passed: #{passed_count}"
puts "Failed: #{test_count - passed_count}"

if passed_count == test_count
  puts
  puts "🎉 ALL TESTS PASSED! 🎉"
  puts
  puts "V2 DSL is 100% backward compatible with V1!"
  exit 0
else
  puts
  puts "❌ Some tests failed"
  exit 1
end
