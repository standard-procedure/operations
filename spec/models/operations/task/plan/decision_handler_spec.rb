require "rails_helper"

RSpec.describe Operations::Task::Plan::DecisionHandler do
  let(:decision_name) { :test_decision }
  let(:empty_config) { proc {} }
  let(:handler) { described_class.new(decision_name, &empty_config) }

  describe "#initialize" do
    it "initializes empty arrays for conditions and destinations" do
      expect(handler.instance_variable_get(:@conditions)).to eq []
      expect(handler.instance_variable_get(:@destinations)).to eq []
    end

    it "initializes true_state and false_state as nil" do
      expect(handler.instance_variable_get(:@true_state)).to be_nil
      expect(handler.instance_variable_get(:@false_state)).to be_nil
    end

    it "evaluates the configuration block" do
      config = proc do
        condition { true }
        go_to :success
      end
      handler = described_class.new(:test, &config)
      expect(handler.instance_variable_get(:@conditions).size).to eq 1
      expect(handler.instance_variable_get(:@destinations)).to eq [:success]
    end
  end

  describe "#immediate?" do
    it "returns true" do
      expect(handler.immediate?).to be true
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

  describe "#if_true" do
    it "sets the true_state" do
      handler = described_class.new(:test) do
        if_true :success_state
      end
      expect(handler.instance_variable_get(:@true_state)).to eq :success_state
    end

    it "accepts a block as true_state" do
      block = proc { "success" }
      handler = described_class.new(:test) do
        if_true(&block)
      end
      expect(handler.instance_variable_get(:@true_state)).to eq block
    end
  end

  describe "#if_false" do
    it "sets the false_state" do
      handler = described_class.new(:test) do
        if_false :failure_state
      end
      expect(handler.instance_variable_get(:@false_state)).to eq :failure_state
    end

    it "accepts a block as false_state" do
      block = proc { "failure" }
      handler = described_class.new(:test) do
        if_false(&block)
      end
      expect(handler.instance_variable_get(:@false_state)).to eq block
    end
  end

  describe "#call" do
    let(:task_class) do
      Class.new do
        attr_accessor :test_value, :condition_result

        def initialize
          @condition_result = true
        end

        def go_to(state)
          @went_to = state
        end

        attr_reader :went_to

        def instance_eval(&block)
          super
        end
      end
    end

    let(:task) { task_class.new }

    context "with if_true/if_false handlers" do
      it "goes to true_state when condition is true" do
        handler = described_class.new(:test) do
          condition { condition_result }
          if_true :success
          if_false :failure
        end

        task.condition_result = true
        handler.call(task)
        expect(task.went_to).to eq :success
      end

      it "goes to false_state when condition is false" do
        handler = described_class.new(:test) do
          condition { condition_result }
          if_true :success
          if_false :failure
        end

        task.condition_result = false
        handler.call(task)
        expect(task.went_to).to eq :failure
      end

      it "handles nil true_state when condition is true" do
        handler = described_class.new(:test) do
          condition { condition_result }
          if_false :failure
        end

        task.condition_result = true
        handler.call(task)
        expect(task.went_to).to be_nil
      end

      it "handles nil false_state when condition is false" do
        handler = described_class.new(:test) do
          condition { condition_result }
          if_true :success
        end

        task.condition_result = false
        handler.call(task)
        expect(task.went_to).to be_nil
      end
    end

    context "with multiple conditions and go_to destinations" do
      it "goes to the destination for the first matching condition" do
        handler = described_class.new(:test) do
          condition { false }
          go_to :first
          condition { true }
          go_to :second
          condition { true }
          go_to :third
        end

        handler.call(task)
        expect(task.went_to).to eq :second
      end

      it "raises NoDecision when no conditions match" do
        handler = described_class.new(:test_decision) do
          condition { false }
          go_to :first
          condition { false }
          go_to :second
        end

        expect { handler.call(task) }.to raise_error(Operations::NoDecision, "No conditions matched test_decision")
      end

      it "handles complex conditions" do
        task.test_value = 42
        handler = described_class.new(:test) do
          condition { test_value < 10 }
          go_to :small
          condition { test_value < 50 }
          go_to :medium
          condition { test_value >= 50 }
          go_to :large
        end

        handler.call(task)
        expect(task.went_to).to eq :medium
      end
    end

    context "mixed configuration" do
      it "prioritizes if_true/if_false over go_to when both are present" do
        handler = described_class.new(:test) do
          condition { true }
          go_to :goto_destination
          if_true :true_destination
          if_false :false_destination
        end

        handler.call(task)
        expect(task.went_to).to eq :true_destination
      end
    end
  end

  describe "integration with task workflow" do
    # standard:disable Lint/ConstantDefinitionInBlock
    class DecisionHandlerTestTask < Operations::Task
      has_attribute :score, :integer
      has_attribute :grade, :string
      starts_with :evaluate_score

      decision :evaluate_score do
        condition { score >= 90 }
        go_to :assign_a
        condition { score >= 80 }
        go_to :assign_b
        condition { score >= 70 }
        go_to :assign_c
        condition { score < 70 }
        go_to :assign_f
      end

      action :assign_a do
        self.grade = "A"
      end.then :done

      action :assign_b do
        self.grade = "B"
      end.then :done

      action :assign_c do
        self.grade = "C"
      end.then :done

      action :assign_f do
        self.grade = "F"
      end.then :done

      result :done
    end

    class BooleanDecisionTestTask < Operations::Task
      has_attribute :pass, :boolean, default: true
      has_attribute :result_message, :string
      starts_with :check_pass

      decision :check_pass do
        condition { pass }
        if_true :success
        if_false :failure
      end

      action :success do
        self.result_message = "Passed!"
      end.then :done

      action :failure do
        self.result_message = "Failed!"
      end.then :done

      result :done
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    it "works with multiple conditions and go_to syntax" do
      task = DecisionHandlerTestTask.call(score: 85)
      expect(task).to be_completed
      expect(task.grade).to eq "B"
    end

    it "works with if_true/if_false syntax" do
      task = BooleanDecisionTestTask.call(pass: false)
      expect(task).to be_completed
      expect(task.result_message).to eq "Failed!"
    end

    it "raises error when no conditions match" do
      # Create a task class with impossible conditions
      test_class = Class.new(Operations::Task) do
        has_attribute :value, :boolean, default: false
        starts_with :impossible_decision

        decision :impossible_decision do
          condition { false }
          go_to :never_reached
        end

        result :never_reached
      end

      expect {
        test_class.call
      }.to raise_error(Operations::NoDecision, "No conditions matched impossible_decision")
    end
  end
end
