require "rails_helper"

module Operations
  RSpec.describe Task, type: :model do
    describe "configuration" do
      it "declares which parameters are required" do
        definition = Class.new(Task) do
          inputs :first_name, :last_name
        end

        expect(definition.required_inputs).to include :first_name
        expect(definition.required_inputs).to include :last_name
      end

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

    describe "state" do
      it "must be one of the defined states" do
        definition = Class.new(Task) do
          starts_with :authorised?
          decision :authorised? do
            condition { true }
            if_true :completed
            if_false :failed
          end
          result :completed
          result :failed
        end

        task = definition.new state: "not valid"
        expect(task).to_not be_valid
        expect(task.errors).to include(:state)
        task.state = "completed"
        task.validate
        expect(task.errors).to_not include(:state)
      end
    end

    describe "status" do
      it "defaults to 'in_progress'" do
        task = Task.new
        expect(task).to be_in_progress
      end

      # standard:disable Lint/ConstantDefinitionInBlock
      class CompletedStateTest < Task
        starts_with "go"
        action "go" do
          go_to :done
        end
        result "done" do |results|
          results.hello = "world"
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      it "is completed after a result is set" do
        task = CompletedStateTest.call
        expect(task).to be_completed
        expect(task.state).to eq "done"
        expect(task.results.hello).to eq "world"
      end

      # standard:disable Lint/ConstantDefinitionInBlock
      class FailureTest < Task
        starts_with "go"
        action "go" do |_|
          fail_with "BOOM"
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      it "is failed if a failure is declared" do
        task = FailureTest.call
        expect(task).to be_failed
        expect(task.state).to eq "go"
        expect(task.results.failure_message).to eq "BOOM"
      end
    end

    describe "call" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class StartTest < Task
        starts_with "initial"

        action "initial" do
          # nothing
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      it "starts the task in the initial state" do
        task = StartTest.call
        expect(task.state).to eq "initial"
      end

      it "marks the task as 'in progress'" do
        task = StartTest.call
        expect(task).to be_in_progress
      end

      # standard:disable Lint/ConstantDefinitionInBlock
      class InputTest < Task
        inputs :salutation, :name
        starts_with :generate_greeting
        result :generate_greeting do |results|
          results.greeting = [salutation, name, suffix].compact.join(" ")
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      it "raises an Operations::MissingInputsError if the required parameters are not provided" do
        expect { InputTest.call(hello: "world") }.to raise_error(Operations::MissingInputsError)
      end

      it "executes the task if the required parameters are provided" do
        task = InputTest.call salutation: "Greetings", name: "Alice"
        expect(task.results.greeting).to eq "Greetings Alice"
      end

      it "executes the task if optional parameters are provided in addition to the required ones" do
        task = InputTest.call salutation: "Greetings", name: "Alice", suffix: "- lovely to meet you"
        expect(task.results.greeting).to eq "Greetings Alice - lovely to meet you"
      end
    end

    describe "handling exceptions" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class ExceptionTest < Operations::Task
        class MyException < StandardError; end
        starts_with :do_something

        action :do_something do
          go_to take_a_risk
        end

        decision :some_risky_decision do
          condition { raise MyException.new("BOOM") }
          if_true :some_risky_action
          if_false :some_risky_result
        end

        action :some_risky_action do |_|
          raise MyException.new("BOOM")
        end

        result :some_risky_result do |_|
          raise MyException.new("BOOM")
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock
      context "in actions" do
        it "fails and records the exception details" do
          task = ExceptionTest.call take_a_risk: "some_risky_action"
          expect(task).to be_failed
          expect(task.results[:failure_message]).to eq "BOOM"
          expect(task.results[:exception_class]).to eq "Operations::ExceptionTest::MyException"
          expect(task.results[:exception_backtrace]).to be_kind_of(Array)
        end
      end

      context "in decisions" do
        it "fails and records the exception details" do
          task = ExceptionTest.call take_a_risk: "some_risky_decision"
          expect(task).to be_failed
          expect(task.results[:failure_message]).to eq "BOOM"
          expect(task.results[:exception_class]).to eq "Operations::ExceptionTest::MyException"
          expect(task.results[:exception_backtrace]).to be_kind_of(Array)
        end
      end

      context "in results" do
        it "fails and records the exception details" do
          task = ExceptionTest.call take_a_risk: "some_risky_result"
          expect(task).to be_failed
          expect(task.results[:failure_message]).to eq "BOOM"
          expect(task.results[:exception_class]).to eq "Operations::ExceptionTest::MyException"
          expect(task.results[:exception_backtrace]).to be_kind_of(Array)
        end
      end
    end
  end
end
