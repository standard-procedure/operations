require "rails_helper"

module Operations::Task::Plan
  RSpec.describe ResultHandler, type: :model do
    # standard:disable Lint/ConstantDefinitionInBlock
    class ResultHandlerTest < Operations::Task
      starts_with "done"

      result "done" do |results|
        results[:hello] = "world"
      end
    end

    class ResultHandlerInputTest < Operations::Task
      starts_with "done"

      result "done" do |results|
        inputs :greetings
        optional :name

        results[:hello] = greetings
      end
    end

    class ResultHandlerNoOutputTest < Operations::Task
      starts_with :done

      result :done
    end

    # standard:enable Lint/ConstantDefinitionInBlock

    it "records the result" do
      task = ResultHandlerTest.call

      expect(task.results[:hello]).to eq "world"
      expect(task.state).to eq "done"
      expect(task).to be_completed
    end

    it "records no result" do
      task = ResultHandlerNoOutputTest.call

      expect(task.results).to be_empty
      expect(task.state).to eq "done"
      expect(task).to be_completed
    end

    it "raises an ArgumentError if the required inputs are not supplied" do
      expect { ResultHandlerInputTest.call }.to raise_error(ArgumentError)
    end
  end
end
