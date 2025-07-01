require "rails_helper"

RSpec.describe Operations::Task::Plan::ActionHandler do
  let(:action_name) { :test_action }
  let(:action_block) { proc { self.test_value = "executed" } }
  let(:handler) { described_class.new(action_name, &action_block) }

  describe "#initialize" do
    it "stores the action name as a symbol" do
      handler = described_class.new("string_name", &action_block)
      expect(handler.instance_variable_get(:@name)).to eq :string_name
    end

    it "stores the action block" do
      expect(handler.instance_variable_get(:@action)).to eq action_block
    end

    it "initializes next_state as nil" do
      expect(handler.next_state).to be_nil
    end
  end

  describe "#then" do
    it "sets the next_state" do
      next_state = :next_step
      handler.then(next_state)
      expect(handler.next_state).to eq next_state
    end

    it "returns the next_state value" do
      result = handler.then(:next_step)
      expect(result).to eq :next_step
    end
  end

  describe "#immediate?" do
    it "returns true" do
      expect(handler.immediate?).to be true
    end
  end

  describe "#call" do
    let(:task_class) do
      Class.new do
        attr_accessor :test_value

        def go_to(state)
          @went_to = state
        end

        attr_reader :went_to

        def instance_exec(&block)
          super
        end
      end
    end

    let(:task) { task_class.new }

    it "executes the action block in the context of the task" do
      handler.call(task)
      expect(task.test_value).to eq "executed"
    end

    it "calls go_to with nil when no next_state is set" do
      handler.call(task)
      expect(task.went_to).to be_nil
    end

    it "calls go_to with the next_state when set" do
      handler.then(:next_step)
      handler.call(task)
      expect(task.went_to).to eq :next_step
    end

    context "with complex action block" do
      let(:complex_action) do
        proc do
          self.test_value = "start"
          self.test_value += " middle"
          self.test_value += " end"
        end
      end
      let(:handler) { described_class.new(:complex, &complex_action) }

      it "executes the entire block" do
        handler.call(task)
        expect(task.test_value).to eq "start middle end"
      end
    end

    context "when action block raises an error" do
      let(:error_action) { proc { raise StandardError, "test error" } }
      let(:handler) { described_class.new(:error_action, &error_action) }

      it "propagates the error" do
        expect { handler.call(task) }.to raise_error(StandardError, "test error")
      end
    end
  end

  describe "integration with task workflow" do
    # standard:disable Lint/ConstantDefinitionInBlock
    class ActionHandlerTestTask < Operations::Task
      has_attribute :test_value, :string
      has_attribute :step_count, :integer, default: 0

      action :start do
        self.test_value = "initialized"
        self.step_count = 1
      end.then :middle

      action :middle do
        self.test_value += " processed"
        self.step_count += 1
      end.then :done

      result :done
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    it "works within a complete task workflow" do
      task = ActionHandlerTestTask.call
      expect(task).to be_completed
      expect(task.test_value).to eq "initialized processed"
      expect(task.step_count).to eq 2
    end
  end
end
