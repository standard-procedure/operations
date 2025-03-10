require "rails_helper"

module Operations::Task::StateManagement
  RSpec.describe ActionHandler, type: :model do
    # We've removed the runtime transitions test since they're no longer supported

    context "defined with static transitions" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class ActionHandlerStaticTest < Operations::Task
        inputs :target_state
        starts_with :get_started

        action :get_started do
          self.i_was_here = true
        end
        go_to :choose_where_to_go

        decision "choose_where_to_go" do
          condition { target_state == "first_target" }
          go_to :first_target
          condition { target_state == "second_target" }
          go_to :second_target
        end

        action "first_target" do
          raise "I should not be here" unless i_was_here
        end

        action "second_target" do
          raise "I should not be here" unless i_was_here
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      it "transitions to the statically defined next state" do
        task = ActionHandlerStaticTest.call target_state: "first_target"
        expect(task.state).to eq "first_target"
        expect(task).to be_in_progress
      end

      it "uses the dynamic input value to determine which state to go to" do
        # The target_state input is used to set the state transition from the do_something action
        task = ActionHandlerStaticTest.call target_state: "second_target"
        expect(task.state).to eq "second_target"
        expect(task).to be_in_progress
      end
    end
  end
end
