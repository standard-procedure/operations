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
  end
end
