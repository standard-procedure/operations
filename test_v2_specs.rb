#!/usr/bin/env ruby

# Simple test runner for V2 specs
require_relative "lib/operations/v2"
require_relative "spec/v2/v2_spec_helper"

puts "=" * 80
puts "Running V2 Example Specs"
puts "=" * 80
puts

# Load all spec files
spec_files = Dir["spec/v2/examples/*_spec.rb"]

spec_files.each do |spec_file|
  puts "\nLoading: #{spec_file}"
  require_relative spec_file
end

puts "\n" + "=" * 80
puts "All specs loaded successfully!"
puts "=" * 80

# Check if RSpec is available
begin
  require 'rspec/core'

  puts "\nRunning RSpec tests..."
  puts "=" * 80

  # Run RSpec
  RSpec::Core::Runner.run(["spec/v2/examples"])
rescue LoadError
  puts "\nRSpec not available. Specs loaded but not executed."
  puts "To run tests, install RSpec: gem install rspec"
  puts "Then run: rspec spec/v2/examples"
end
