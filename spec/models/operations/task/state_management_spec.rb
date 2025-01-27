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
          ends_with :all_done do |results|
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

        data :hello, :string, default: "World"
        data :number, :integer, default: 123

        action "initial" do
          self.hello = "Goodbye"
        end
      end
      # standard:disable Lint/ConstantDefinitionInBlock

      it "starts the task in the initial state" do
        task = StartTest.start
        expect(task.state).to eq "initial"
      end

      it "sets any given attributes" do
        task = StartTest.start number: 999
        expect(task.number).to eq 999
      end

      it "runs the handler for the initial state" do
        task = StartTest.start
        expect(task.hello).to eq "Goodbye"
      end
    end

    describe "action handlers" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class ActionHandlerTest < Task
        data :next_state, :string
        data :i_was_here, :boolean, default: false

        starts_with "do_something"

        action "do_something" do
          self.i_was_here = true
          go_to next_state
        end

        action "this" do
          # nothing
        end

        action "that" do
          # nothing
        end
      end
      # standard:disable Lint/ConstantDefinitionInBlock

      it "runs the action" do
        task = ActionHandlerTest.start next_state: "this", i_was_here: false
        expect(task.i_was_here).to eq true
        expect(task.state).to eq "this"
        expect(task).to be_active

        task = ActionHandlerTest.start next_state: "that", i_was_here: false
        expect(task.i_was_here).to eq true
        expect(task.state).to eq "that"
        expect(task).to be_active
      end
    end

    describe "decision handlers" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class DecisionHandlerTest < Task
        data :value, :boolean
        data :choice, :string, default: "???"

        starts_with "choose"

        decision "choose" do
          condition { value? }
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
      # standard:disable Lint/ConstantDefinitionInBlock

      it "runs the true handler" do
        task = DecisionHandlerTest.start value: true
        expect(task.state).to eq "truth"
        expect(task.choice).to eq "truth"
        expect(task).to be_active
      end

      it "runs the false handler" do
        task = DecisionHandlerTest.start value: false
        expect(task.state).to eq "lies"
        expect(task.choice).to eq "lies"
        expect(task).to be_active
      end
    end

    describe "completion handlers" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class CompletionHandlerTest < Task
        starts_with "done"
        ends_with "done" do |results|
          results[:hello] = "world"
        end
      end
      # standard:disable Lint/ConstantDefinitionInBlock

      it "records the result" do
        task = CompletionHandlerTest.start
        expect(task.results).to eq(hello: "world")
        expect(task).to be_completed
      end
    end
  end
end
