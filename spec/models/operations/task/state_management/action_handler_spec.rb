require "rails_helper"

module Operations::Task::StateManagement
  RSpec.describe ActionHandler, type: :model do
    # We've removed the runtime transitions test since they're no longer supported

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

    context "attempting to use runtime transitions" do
      it "cannot call go_to in an action block" do
        # Create a data carrier and try to call go_to on it directly to prove it doesn't exist
        data_carrier = Operations::Task::DataCarrier.new(task: nil)
        expect { data_carrier.go_to("any_state") }.to raise_error(NoMethodError, /undefined method `go_to'/)
      end
    end
  end
end
