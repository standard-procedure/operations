require "rails_helper"

RSpec.describe Operations::Task::Plan::WaitHandler do
  let(:wait_name) { :test_wait }
  let(:empty_config) { proc {} }
  let(:handler) { described_class.new(wait_name, &empty_config) }

  describe "#initialize" do
    it "evaluates the configuration block" do
      config = proc do
        condition { true }
        go_to :next_state
      end
      handler = described_class.new(:test, &config)
      expect(handler.instance_variable_get(:@conditions).size).to eq 1
      expect(handler.instance_variable_get(:@destinations)).to eq [:next_state]
    end
  end

  describe "#immediate?" do
    it "returns false" do
      expect(handler.immediate?).to be false
    end
  end

  describe "#condition" do
    it "adds conditions to the conditions array" do
      handler = described_class.new(:test) do
        condition { true }
        condition { false }
      end
      expect(handler.instance_variable_get(:@conditions).size).to eq 2
    end

    it "stores condition labels when provided" do
      handler = described_class.new(:test) do
        condition(label: "first condition") { true }
        condition(label: "second condition") { false }
      end
      condition_labels = handler.condition_labels
      expect(condition_labels[0]).to eq "first condition"
      expect(condition_labels[1]).to eq "second condition"
    end

    it "handles conditions without labels" do
      handler = described_class.new(:test) do
        condition { true }
        condition { false }
      end
      condition_labels = handler.condition_labels
      expect(condition_labels[0]).to be_nil
      expect(condition_labels[1]).to be_nil
    end
  end

  describe "#go_to" do
    it "adds destinations to the destinations array" do
      handler = described_class.new(:test) do
        go_to :state1
        go_to :state2
      end
      expect(handler.instance_variable_get(:@destinations)).to eq [:state1, :state2]
    end
  end

  describe "#condition_labels" do
    it "returns empty hash when no labels are set" do
      expect(handler.condition_labels).to eq({})
    end

    it "returns hash with condition labels" do
      handler = described_class.new(:test) do
        condition(label: "test label") { true }
      end
      expect(handler.condition_labels).to eq({0 => "test label"})
    end
  end

  describe "#call" do
    let(:task_class) do
      Class.new do
        attr_accessor :test_value, :current_state

        def initialize
          @current_state = :waiting_state
        end

        def go_to(state)
          @went_to = state
        end

        attr_reader :went_to

        def instance_eval(&block)
          super
        end

        def to_s
          "TestTask"
        end
      end
    end

    let(:task) { task_class.new }

    before do
      allow(Rails.logger).to receive(:debug)
    end

    it "logs debug message when called" do
      handler.call(task)
      expect(Rails.logger).to have_received(:debug)
    end

    context "when no conditions are met" do
      it "goes to current state (stays in wait)" do
        handler = described_class.new(:test) do
          condition { false }
          go_to :next_state
        end
        allow(task).to receive(:go_to)
        handler.call(task)
        expect(task).to have_received(:go_to).with(:waiting_state)
      end
    end

    context "when a condition is met" do
      it "goes to the corresponding destination" do
        handler = described_class.new(:test) do
          condition { test_value == "trigger" }
          go_to :success_state
        end
        task.test_value = "trigger"
        allow(task).to receive(:go_to)
        handler.call(task)
        expect(task).to have_received(:go_to).with(:success_state)
      end

      it "goes to the first matching condition's destination" do
        handler = described_class.new(:test) do
          condition { false }
          go_to :first_state
          condition { true }
          go_to :second_state
          condition { true }
          go_to :third_state
        end
        allow(task).to receive(:go_to)
        handler.call(task)
        expect(task).to have_received(:go_to).with(:second_state)
      end
    end

    context "with multiple conditions and destinations" do
      it "evaluates conditions in order" do
        task.test_value = 25
        handler = described_class.new(:test) do
          condition { test_value < 10 }
          go_to :small
          condition { test_value < 50 }
          go_to :medium
          condition { test_value >= 50 }
          go_to :large
        end
        allow(task).to receive(:go_to)
        handler.call(task)
        expect(task).to have_received(:go_to).with(:medium)
      end

      it "handles complex condition logic" do
        task.test_value = "important"
        handler = described_class.new(:test) do
          condition { test_value.nil? }
          go_to :nil_state
          condition { test_value.include?("important") }
          go_to :important_state
          condition { test_value.length > 5 }
          go_to :long_state
        end
        allow(task).to receive(:go_to)
        handler.call(task)
        expect(task).to have_received(:go_to).with(:important_state)
      end
    end

    context "when condition raises an error" do
      it "propagates the error" do
        handler = described_class.new(:test) do
          condition { raise StandardError, "condition error" }
          go_to :error_state
        end
        expect { handler.call(task) }.to raise_error(StandardError, "condition error")
      end
    end
  end

  describe "integration with task workflow" do
    # standard:disable Lint/ConstantDefinitionInBlock
    class WaitHandlerTestTask < Operations::Task
      has_attribute :ready, :boolean, default: false
      has_attribute :stage, :string
      starts_with :check_readiness

      wait_until :check_readiness do
        condition { ready }
        go_to :process
      end

      action :process do
        self.stage = "processed"
      end.then :done

      result :done
    end

    class MultipleConditionsWaitTask < Operations::Task
      has_attribute :score, :integer
      has_attribute :approved, :boolean, default: false
      has_attribute :result_message, :string
      starts_with :wait_for_approval

      wait_until :wait_for_approval do
        condition(label: "high score approval") { score >= 90 && approved }
        go_to :auto_approve
        condition(label: "manual approval") { approved }
        go_to :manual_approve
        condition(label: "timeout check") { score < 50 }
        go_to :reject
      end

      action :auto_approve do
        self.result_message = "Auto-approved for high score"
      end.then :done

      action :manual_approve do
        self.result_message = "Manually approved"
      end.then :done

      action :reject do
        self.result_message = "Rejected - score too low"
      end.then :done

      result :done
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    # Cannot test because the task loop blocks and expects another thread/process to interact with the waiting task
    # it "waits until condition is met" do
    #   task = WaitHandlerTestTask.call
    #   expect(task).to be_waiting
    #   expect(task.current_state).to eq "check_readiness"

    #   # Condition not met, task should still be waiting
    #   task.wake_up!
    #   expect(task).to be_waiting

    #   # Set condition and wake up
    #   task.update!(ready: true)
    #   task.wake_up!
    #   expect(task).to be_completed
    #   expect(task.stage).to eq "processed"
    # end

    it "works with multiple conditions and labeled conditions" do
      # Test high score auto-approval
      task1 = MultipleConditionsWaitTask.call(score: 95, approved: true)
      task1.wake_up!
      expect(task1).to be_completed
      expect(task1.result_message).to eq "Auto-approved for high score"

      # Test manual approval
      task2 = MultipleConditionsWaitTask.call(score: 75, approved: true)
      task2.wake_up!
      expect(task2).to be_completed
      expect(task2.result_message).to eq "Manually approved"

      # Test rejection
      task3 = MultipleConditionsWaitTask.call(score: 40)
      task3.wake_up!
      expect(task3).to be_completed
      expect(task3.result_message).to eq "Rejected - score too low"
    end

    # Cannot test because the task loop blocks and expects another thread/process to interact with the waiting task
    # it "stays in wait state when no conditions are met" do
    #   task = MultipleConditionsWaitTask.call(score: 60, approved: false)
    #   expect(task).to be_waiting
    #   task.wake_up!
    #   expect(task).to be_waiting
    #   expect(task.current_state).to eq "wait_for_approval"
    # end
  end
end
