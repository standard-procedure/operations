# Shared examples for testing Executor Adapter compatibility
# All executor adapters must pass these tests to be compatible with Operations V2
RSpec.shared_examples "Operations V2 Executor Adapter" do
  # The including spec must define:
  # - `let(:storage)` - storage adapter to use
  # - `let(:executor)` - executor adapter under test

  # Simple task for testing
  before(:all) do
    unless defined?(ExecutorTestTask)
      class ExecutorTestTask < Operations::V2::Task
        has_attribute :steps, :string, default: ""

        starts_with :step_one

        action :step_one do
          self.steps += "1"
        end
        go_to :step_two

        action :step_two do
          self.steps += "2"
        end
        go_to :done

        result :done
      end
    end
  end

  before(:each) do
    # Configure V2 to use the storage and executor under test
    Operations::V2.configure do |config|
      config.storage = storage
      config.executor = executor
    end
  end

  describe "#call" do
    it "executes the task state machine" do
      task = ExecutorTestTask.new
      storage.save(task)

      executor.call(task)

      expect(task.steps).to eq "12"
      expect(task).to be_completed
      expect(task.current_state).to eq "done"
    end

    it "handles exceptions and marks task as failed" do
      unless defined?(FailingTask)
        class FailingTask < Operations::V2::Task
          starts_with :fail_step

          action :fail_step do
            raise StandardError, "Something went wrong"
          end
        end
      end

      task = FailingTask.new
      storage.save(task)

      expect { executor.call(task) }.to raise_error(StandardError)

      expect(task).to be_failed
      expect(task.exception_class).to eq "StandardError"
      expect(task.exception_message).to eq "Something went wrong"
    end
  end

  describe "#later" do
    it "executes the task eventually" do
      task = ExecutorTestTask.new
      storage.save(task)

      # For inline executors, this runs immediately
      # For async executors, this queues for later execution
      executor.later(task)

      # Give async executors a moment to process
      # For inline executors this is a no-op
      sleep 0.1 if defined?(Operations::V2::Adapters::Executor::Async)

      # Reload task to see latest state
      task = storage.find(task.id)
      expect(task.steps).to eq "12"
      expect(task).to be_completed
    end
  end

  describe "#wake" do
    before(:all) do
      unless defined?(SleepingTask)
        class SleepingTask < Operations::V2::Task
          has_attribute :woken, :boolean, default: false

          starts_with :sleep_state

          wait_until :sleep_state do
            condition { woken? }
            go_to :wake_up
          end

          interaction :wake! do
            self.woken = true
          end

          action :wake_up do
            self.result = "awake"
          end
          go_to :done

          result :done
        end
      end
    end

    it "wakes up a sleeping task and continues execution" do
      task = SleepingTask.call
      expect(task).to be_waiting

      # Simulate external interaction
      task.woken = true
      storage.save(task)

      executor.wake(task)

      expect(task).to be_completed
      expect(task.result).to eq "awake"
    end
  end
end
