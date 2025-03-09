require "rails_helper"

module Operations::Task::StateManagement
  RSpec.describe ActionHandler, type: :model do
    context "defined on the action with runtime transitions" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class ActionHandlerRuntimeTest < Operations::Task
        starts_with "do_something"

        action "do_something" do
          inputs :next_state
          optional :something_else

          self.i_was_here = true
          go_to next_state
        end

        action "this" do
          raise "I should not be here" unless i_was_here
        end

        action "that" do
          raise "I should not be here" unless i_was_here
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      it "raises an ArgumentError if the required inputs are not supplied" do
        expect { ActionHandlerRuntimeTest.call }.to raise_error(ArgumentError)
      end

      it "runs the action" do
        task = ActionHandlerRuntimeTest.call next_state: "this"
        expect(task.state).to eq "this"

        task = ActionHandlerRuntimeTest.call next_state: "that"
        expect(task.state).to eq "that"
        expect(task).to be_in_progress
      end

      it "does not complete the task" do
        task = ActionHandlerRuntimeTest.call next_state: "that"
        expect(task).to be_in_progress
      end
    end

    context "defined with static transitions" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class ActionHandlerStaticTest < Operations::Task
        starts_with "do_something"

        action "do_something", inputs: [:target_state], optional: [:something_else] do
          # Since DataCarrier is an OpenStruct, we can set properties directly
          self.i_was_here = true
        end
        goto :target_state, from: "do_something"

        action "target_state" do
          raise "I should not be here" unless i_was_here
        end

        action "different_target" do
          raise "I should not be here" unless i_was_here
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      it "transitions to the statically defined next state" do
        task = ActionHandlerStaticTest.call target_state: "target_state"
        expect(task.state).to eq "target_state"
        expect(task).to be_in_progress
      end

      it "uses the dynamic input value to determine which state to go to" do
        # The target_state input is used to set the state transition from the do_something action
        task = ActionHandlerStaticTest.call target_state: "different_target"
        expect(task.state).to eq "different_target"
        expect(task).to be_in_progress
      end
    end
  end
end
