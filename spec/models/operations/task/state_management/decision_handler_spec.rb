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
        expect(DecisionHandlerTest.call).to be_failed
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

    context "defined by a method" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class InlineDecisionHandlerTest < Operations::Task
        starts_with "truth_or_lies?"

        decision "truth_or_lies?" do
          if_true "truth"
          if_false "lies"
        end
        action "truth" do
          self.choice = "truth"
        end
        action "lies" do
          self.choice = "lies"
        end

        private def truth_or_lies?(data) = data.value
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      it "runs the true handler" do
        task = InlineDecisionHandlerTest.call value: true
        expect(task.state).to eq "truth"
        expect(task).to be_in_progress
      end

      it "runs the false handler" do
        task = InlineDecisionHandlerTest.call value: false
        expect(task.state).to eq "lies"
        expect(task).to be_in_progress
      end

      it "does not complete the task" do
        task = InlineDecisionHandlerTest.call value: false
        expect(task).to be_in_progress
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
        task = DecisionFailureTest.call value: true
        expect(task).to be_failed
        expect(task.state).to eq "choose"
        expect(task.results[:failure_message]).to eq "truth"
      end

      it "fails in the false handler" do
        task = DecisionFailureTest.call value: false
        expect(task).to be_failed
        expect(task.state).to eq "choose"
        expect(task.results[:failure_message]).to eq "lies"
      end
    end
  end
end
