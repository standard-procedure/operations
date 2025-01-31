require "rails_helper"

module Operations::Task::StateManagement
  RSpec.describe ActionHandler, type: :model do
    context "defined on the action" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class ActionHandlerTest < Operations::Task
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

      it "fails if the required inputs are not supplied" do
        expect(ActionHandlerTest.call).to be_failed
      end

      it "runs the action" do
        task = ActionHandlerTest.call next_state: "this"
        expect(task.state).to eq "this"

        task = ActionHandlerTest.call next_state: "that"
        expect(task.state).to eq "that"
        expect(task).to be_in_progress
      end

      it "does not complete the task" do
        task = ActionHandlerTest.call next_state: "that"
        expect(task).to be_in_progress
      end
    end

    context "defined by a method" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class InlineActionHandlerTest < Operations::Task
        starts_with "do_something"

        action "do_something"

        action "this" do
          # nothing
        end

        action "that" do
          # nothing
        end

        private def do_something(data)
          data[:i_was_here] = true
          go_to data[:next_state]
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      it "runs the action" do
        task = InlineActionHandlerTest.call next_state: "this", i_was_here: false
        expect(task.state).to eq "this"

        task = InlineActionHandlerTest.call next_state: "that", i_was_here: false
        expect(task.state).to eq "that"
      end

      it "does not complete the task" do
        task = InlineActionHandlerTest.call next_state: "that", i_was_here: false
        expect(task).to be_in_progress
      end
    end
  end
end
