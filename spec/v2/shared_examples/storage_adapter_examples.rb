# Shared examples for testing Storage Adapter compatibility
# All storage adapters must pass these tests to be compatible with Operations V2
RSpec.shared_examples "Operations V2 Storage Adapter" do
  # The including spec must define `let(:storage)` that returns a configured storage adapter instance

  # Simple task for testing
  before(:all) do
    unless defined?(SimpleTaskExample)
      class SimpleTaskExample < Operations::V2::Task
        has_attribute :name, :string
        has_attribute :count, :integer, default: 0

        starts_with :increment

        action :increment do
          self.count += 1
        end
        go_to :done

        result :done
      end
    end
  end

  before(:each) do
    # Configure V2 to use the storage under test
    Operations::V2.configure do |config|
      config.storage = storage
    end
  end

  describe "#save" do
    it "saves a new task and assigns an ID" do
      task = SimpleTaskExample.new(name: "Test")
      expect(task.id).to be_nil

      storage.save(task)

      expect(task.id).to_not be_nil
      expect(task.updated_at).to_not be_nil
    end

    it "updates an existing task" do
      task = SimpleTaskExample.new(name: "Test")
      storage.save(task)
      original_id = task.id
      first_updated = task.updated_at

      sleep 0.01 # Ensure timestamp changes
      task.count = 5
      storage.save(task)

      expect(task.id).to eq original_id
      expect(task.updated_at).to be > first_updated
    end
  end

  describe "#find" do
    it "finds a saved task by ID" do
      task = SimpleTaskExample.new(name: "FindMe", count: 42)
      storage.save(task)

      found = storage.find(task.id)

      expect(found).to_not be_nil
      expect(found.id).to eq task.id
      expect(found.name).to eq "FindMe"
      expect(found.count).to eq 42
    end

    it "returns nil for non-existent ID" do
      found = storage.find("non-existent-id")
      expect(found).to be_nil
    end

    it "restores task to correct class" do
      task = SimpleTaskExample.new(name: "Test")
      storage.save(task)

      found = storage.find(task.id)
      expect(found).to be_a(SimpleTaskExample)
    end
  end

  describe "#sleeping_tasks" do
    it "returns tasks that are waiting and ready to wake" do
      task1 = SimpleTaskExample.new(name: "Ready", status: :waiting, wake_at: Time.now.utc - 60)
      task2 = SimpleTaskExample.new(name: "NotReady", status: :waiting, wake_at: Time.now.utc + 3600)
      task3 = SimpleTaskExample.new(name: "Active", status: :active)

      storage.save(task1)
      storage.save(task2)
      storage.save(task3)

      sleeping = storage.sleeping_tasks

      expect(sleeping.size).to eq 1
      expect(sleeping.first.name).to eq "Ready"
    end

    it "filters by task class when provided" do
      unless defined?(AnotherTaskExample)
        class AnotherTaskExample < Operations::V2::Task
          has_attribute :name, :string
          starts_with :start
          result :start
        end
      end

      task1 = SimpleTaskExample.new(name: "Simple", status: :waiting, wake_at: Time.now.utc - 60)
      task2 = AnotherTaskExample.new(name: "Another", status: :waiting, wake_at: Time.now.utc - 60)

      storage.save(task1)
      storage.save(task2)

      sleeping = storage.sleeping_tasks(SimpleTaskExample)

      expect(sleeping.size).to eq 1
      expect(sleeping.first).to be_a(SimpleTaskExample)
    end
  end

  describe "#sub_tasks_of" do
    it "returns child tasks of a parent" do
      parent = SimpleTaskExample.new(name: "Parent")
      storage.save(parent)

      child1 = SimpleTaskExample.new(name: "Child1", parent_task_id: parent.id)
      child2 = SimpleTaskExample.new(name: "Child2", parent_task_id: parent.id)
      other = SimpleTaskExample.new(name: "Other")

      storage.save(child1)
      storage.save(child2)
      storage.save(other)

      sub_tasks = storage.sub_tasks_of(parent)

      expect(sub_tasks.size).to eq 2
      expect(sub_tasks.map(&:name)).to contain_exactly("Child1", "Child2")
    end

    it "returns empty array when no sub-tasks" do
      parent = SimpleTaskExample.new(name: "Parent")
      storage.save(parent)

      sub_tasks = storage.sub_tasks_of(parent)
      expect(sub_tasks).to eq []
    end
  end

  describe "#delete_old" do
    it "deletes tasks older than specified time" do
      old = SimpleTaskExample.new(name: "Old", delete_at: Time.now.utc - 60)
      recent = SimpleTaskExample.new(name: "Recent", delete_at: Time.now.utc + 3600)

      storage.save(old)
      storage.save(recent)

      deleted_count = storage.delete_old(before: Time.now.utc)

      expect(deleted_count).to eq 1
      expect(storage.find(old.id)).to be_nil
      expect(storage.find(recent.id)).to_not be_nil
    end

    it "filters by task class when provided" do
      unless defined?(AnotherTaskExample)
        class AnotherTaskExample < Operations::V2::Task
          has_attribute :name, :string
          starts_with :start
          result :start
        end
      end

      old_simple = SimpleTaskExample.new(name: "OldSimple", delete_at: Time.now.utc - 60)
      old_another = AnotherTaskExample.new(name: "OldAnother", delete_at: Time.now.utc - 60)

      storage.save(old_simple)
      storage.save(old_another)

      deleted_count = storage.delete_old(SimpleTaskExample, before: Time.now.utc)

      expect(deleted_count).to eq 1
      expect(storage.find(old_simple.id)).to be_nil
      expect(storage.find(old_another.id)).to_not be_nil
    end
  end

  describe "Model serialization" do
    before(:all) do
      unless defined?(MockModel)
        class MockModel
          attr_accessor :id, :name

          @@store = {}
          @@next_id = 1

          def self.create!(attrs)
            model = new
            model.id = @@next_id
            @@next_id += 1
            model.name = attrs[:name]
            @@store[model.id] = model
            model
          end

          def self.find(id)
            @@store[id]
          end

          def self.reset!
            @@store = {}
            @@next_id = 1
          end
        end

        class TaskWithModelExample < Operations::V2::Task
          has_model :user, "MockModel"
          has_models :items, "MockModel"

          starts_with :done
          result :done
        end
      end
    end

    before(:each) do
      MockModel.reset!
    end

    it "serializes and deserializes has_model" do
      user = MockModel.create!(name: "Alice")
      task = TaskWithModelExample.new(user: user)
      storage.save(task)

      found = storage.find(task.id)
      expect(found.user).to be_a(MockModel)
      expect(found.user.id).to eq user.id
      expect(found.user.name).to eq "Alice"
    end

    it "serializes and deserializes has_models" do
      item1 = MockModel.create!(name: "Item1")
      item2 = MockModel.create!(name: "Item2")
      task = TaskWithModelExample.new(items: [item1, item2])
      storage.save(task)

      found = storage.find(task.id)
      expect(found.items).to be_an(Array)
      expect(found.items.size).to eq 2
      expect(found.items.map(&:name)).to contain_exactly("Item1", "Item2")
    end
  end
end
