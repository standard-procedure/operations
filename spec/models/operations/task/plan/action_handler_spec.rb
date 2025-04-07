require "rails_helper"

module Operations::Task::Plan
  RSpec.describe ActionHandler, type: :model do
    # standard:disable Lint/ConstantDefinitionInBlock
    class ActionHandlerTest < Operations::Task
      inputs :target_state
      starts_with :get_started

      action :get_started do
        self.i_was_here = true
      end
      go_to :first_target

      action "first_target" do
        raise "I should not be here" unless i_was_here
      end

      action "second_target" do
        raise "I should not be here" unless i_was_here
      end
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    it "transitions to the next state" do
      task = ActionHandlerTest.call target_state: "first_target"
      expect(task.state).to eq "first_target"
      expect(task).to be_in_progress
    end
  end
end
