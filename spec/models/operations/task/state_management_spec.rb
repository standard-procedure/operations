require "rails_helper"

module Operations
  RSpec.describe Task::StateManagement, type: :model do
    describe "configuration" do
      it "declares the initial state" do
        definition = Class.new(Task) do
          starts_with "you_are_here"
        end
        expect(definition.initial_state).to eq :you_are_here
      end

      it "declares a decision handler" do
        definition = Class.new(Task) do
          decision :is_it_done? do
            condition { rand(2) == 0 }
            if_true :done
            if_false :not_done
          end
        end

        handler = definition.handler_for(:is_it_done?)
        expect(handler).to_not be_nil
      end

      it "declares an action handler" do
        definition = Class.new(Task) do
          action :do_something do
            # whatever
            go_to :i_did_it
          end
        end

        handler = definition.handler_for(:do_something)
        expect(handler).to_not be_nil
      end

      it "declares a completed handler" do
        definition = Class.new(Task) do
          result :all_done do |results|
            results[:job] = "done"
          end
        end

        handler = definition.handler_for(:all_done)
        expect(handler).to_not be_nil
      end
    end

    describe "start" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class StartTest < Task
        starts_with "initial"

        action "initial" do
          # do nothing
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      it "starts the task in the initial state" do
        task = StartTest.call
        expect(task.state).to eq "initial"
      end
    end

    describe "action handlers" do
      context "defined on the action" do
        # standard:disable Lint/ConstantDefinitionInBlock
        class ActionHandlerTest < Task
          starts_with "do_something"

          action "do_something" do |data|
            data[:i_was_here] = true
            go_to data[:next_state], data
          end

          action "this" do |data|
            raise "I should not be here" unless data[:i_was_here]
          end

          action "that" do |data|
            raise "I should not be here" unless data[:i_was_here]
          end
        end
        # standard:enable Lint/ConstantDefinitionInBlock

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
        class InlineActionHandlerTest < Task
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

    describe "decision handlers" do
      context "defined by a condition on the decision" do
        # standard:disable Lint/ConstantDefinitionInBlock
        class DecisionHandlerTest < Task
          starts_with "choose"

          decision "choose" do
            condition { |data| data[:value] == true }
            if_true "truth"
            if_false "lies"
          end

          action "truth" do |data|
            data[:choice] = "truth"
          end

          action "lies" do |data|
            data[:choice] = "lies"
          end
        end
        # standard:enable Lint/ConstantDefinitionInBlock

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
        class InlineDecisionHandlerTest < Task
          starts_with "truth_or_lies?"

          decision "truth_or_lies?" do
            if_true "truth"
            if_false "lies"
          end
          action "truth" do |data|
            data[:choice] = "truth"
          end
          action "lies" do |data|
            data[:choice] = "lies"
          end

          private def truth_or_lies?(data) = data[:value]
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
        class DecisionFailureTest < Task
          starts_with "choose"

          decision "choose" do
            condition { |data| data[:value] == true }
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

    describe "completion handlers" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class CompletionHandlerTest < Task
        starts_with "done"
        result "done" do |data, results|
          results[:hello] = "world"
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      it "records the result" do
        task = CompletionHandlerTest.call
        expect(task.results).to eq(hello: "world")
        expect(task).to be_completed
      end
    end
  end
end
