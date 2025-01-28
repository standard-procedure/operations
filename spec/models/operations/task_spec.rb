require "rails_helper"

module Operations
  RSpec.describe Task, type: :model do
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
        action "go" do |_|
          go_to :done
        end
        result "done" do |_, results|
          results[:hello] = "world"
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      it "is completed after a result is set" do
        task = CompletedStateTest.call
        expect(task).to be_completed
        expect(task.state).to eq "done"
        expect(task.results).to eq(hello: "world")
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
        expect(task.results).to eq(failure_message: "BOOM")
      end
    end

    describe "call" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class StartTest < Task
        starts_with "initial"

        action "initial" do |_|
          # nothing
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      it "starts the task in the initial state" do
        task = StartTest.call
        expect(task.state).to eq "initial"
      end

      it "is in progress" do
        task = StartTest.call
        expect(task).to be_in_progress
      end
    end

    describe "handling exceptions" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class ExceptionTest < Operations::Task
        class MyException < StandardError; end
        starts_with :do_something

        action :do_something do |data|
          go_to data[:take_a_risk]
        end

        decision :some_risky_decision do |_|
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
        it "records the exception " do
          task = ExceptionTest.call take_a_risk: "some_risky_action"
          expect(task).to be_failed
          expect(task.results[:exception_message]).to eq "BOOM"
          expect(task.results[:exception_class]).to eq "Operations::ExceptionTest::MyException"
          expect(task.results[:exception_backtrace]).to be_kind_of(Array)
        end
      end

      context "in decisions" do
        it "records the exception " do
          task = ExceptionTest.call take_a_risk: "some_risky_decision"
          expect(task).to be_failed
          expect(task.results[:exception_message]).to eq "BOOM"
          expect(task.results[:exception_class]).to eq "Operations::ExceptionTest::MyException"
          expect(task.results[:exception_backtrace]).to be_kind_of(Array)
        end
      end

      context "in results" do
        it "records the exception " do
          task = ExceptionTest.call take_a_risk: "some_risky_result"
          expect(task).to be_failed
          expect(task.results[:exception_message]).to eq "BOOM"
          expect(task.results[:exception_class]).to eq "Operations::ExceptionTest::MyException"
          expect(task.results[:exception_backtrace]).to be_kind_of(Array)
        end
      end
    end
  end
end
