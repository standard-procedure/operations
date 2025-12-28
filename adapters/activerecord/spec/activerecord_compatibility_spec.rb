# ActiveRecord Storage Adapter Compatibility Suite
#
# This spec verifies that the ActiveRecord storage adapter is fully compatible
# with Operations V2 by running the shared compatibility examples.
#
# To run these tests:
#   cd adapters/activerecord
#   bundle exec rspec

require "spec_helper"

RSpec.describe "ActiveRecord Storage Adapter Compatibility" do
  # Configure the ActiveRecord adapter for testing
  let(:storage) { Operations::Adapters::Storage::ActiveRecord.new }
  let(:executor) { Operations::V2::Adapters::Executor::Inline.new }

  before(:each) do
    # Set up test database
    Operations::TaskRecord.delete_all

    # Configure Operations V2 to use ActiveRecord storage
    Operations::V2.configure do |config|
      config.storage = storage
      config.executor = executor
    end
  end

  # Run all Task DSL compatibility tests
  # This ensures all DSL features work with ActiveRecord storage
  include_examples "Operations V2 Task DSL"

  # Run all Storage Adapter contract tests
  # This ensures the ActiveRecord adapter implements the full storage contract
  include_examples "Operations V2 Storage Adapter"

  # Run all Executor compatibility tests
  # (Using inline executor, but testing with ActiveRecord storage)
  include_examples "Operations V2 Executor Adapter"

  # Adapter-specific tests can go here
  describe "ActiveRecord-specific features" do
    it "stores tasks in database" do
      unless defined?(SimpleTaskExample)
        class SimpleTaskExample < Operations::V2::Task
          has_attribute :name, :string
          starts_with :done
          result :done
        end
      end

      task = SimpleTaskExample.new(name: "Test")
      storage.save(task)

      record = Operations::TaskRecord.find_by(task_id: task.id)
      expect(record).to_not be_nil
      expect(record.task_type).to eq "SimpleTaskExample"
    end
  end
end
