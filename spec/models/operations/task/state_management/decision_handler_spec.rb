require "rails_helper"

module Operations::Task::StateManagement
  RSpec.describe DecisionHandler, type: :model do
    context "defined by a condition on the decision" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class DecisionHandlerTest < Operations::Task
        starts_with "choose"

        decision "choose" do
          inputs :value
          condition { value == true }

          if_true "truth"
          if_false "lies"
        end

        action "truth" do
          self.choice = "truth"
        end

        action "lies" do
          self.choice = "lies"
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      it "fails if the required input is not provided" do
        expect { DecisionHandlerTest.call }.to raise_error(ArgumentError)
      end

      it "runs the true handler" do
        task = DecisionHandlerTest.call value: true
        expect(task.state).to eq "truth"
      end

      it "runs the false handler" do
        task = DecisionHandlerTest.call value: false
        expect(task.state).to eq "lies"
      end

      it "does not complete the task" do
        task = DecisionHandlerTest.call value: true
        expect(task).to be_in_progress
      end
    end

    context "defined by multiple conditions" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class MultipleDecisionHandlerTest < Operations::Task
        starts_with "choose"

        decision "choose" do
          inputs :value
          condition { value == "a" }
          go_to :value_is_a
          condition { value == "b" }
          go_to :value_is_b
          condition { value == "c" }
          go_to :value_is_c
        end

        result :value_is_a
        result :value_is_b
        result :value_is_c
      end
      # standard:enable Lint/ConstantDefinitionInBlock
      #
      it "fails if the required input is not provided" do
        expect { MultipleDecisionHandlerTest.call }.to raise_error(ArgumentError)
      end

      it "checks if the value is a" do
        task = MultipleDecisionHandlerTest.call value: "a"
        expect(task.state).to eq "value_is_a"
      end

      it "checks if the value is b" do
        task = MultipleDecisionHandlerTest.call value: "b"
        expect(task.state).to eq "value_is_b"
      end

      it "checks if the value is c" do
        task = MultipleDecisionHandlerTest.call value: "c"
        expect(task.state).to eq "value_is_c"
      end

      it "fails if no conditions are met" do
        expect { MultipleDecisionHandlerTest.call(value: "quack") }.to raise_error(Operations::NoDecision)
      end
    end

    context "reporting a failure" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class DecisionFailureTest < Operations::Task
        starts_with "choose"

        decision "choose" do
          condition { value == true }
          if_true { fail_with "truth" }
          if_false { fail_with "lies" }
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      it "fails in the true handler" do
        expect { DecisionFailureTest.call value: true }.to raise_error(Operations::Failure)

        task = DecisionFailureTest.last
        expect(task).to be_failed
        expect(task.state).to eq "choose"
        expect(task.results[:failure_message]).to eq "truth"
      end

      it "fails in the false handler" do
        expect { DecisionFailureTest.call value: false }.to raise_error(Operations::Failure)

        task = DecisionFailureTest.last
        expect(task).to be_failed
        expect(task.state).to eq "choose"
        expect(task.results[:failure_message]).to eq "lies"
      end
    end
  end
end
