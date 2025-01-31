require "rails_helper"

module Operations::Task::StateManagement
  RSpec.describe CompletionHandler, type: :model do
    # standard:disable Lint/ConstantDefinitionInBlock
    class CompletionHandlerTest < Operations::Task
      starts_with "done"

      result "done" do |results|
        results[:hello] = "world"
      end
    end

    class CompletionHandlerInputTest < Operations::Task
      starts_with "done"

      result "done" do |results|
        inputs :greetings
        optional :name

        results[:hello] = greetings
      end
    end

    # standard:enable Lint/ConstantDefinitionInBlock

    it "records the result" do
      task = CompletionHandlerTest.call

      expect(task.results[:hello]).to eq "world"
      expect(task).to be_completed
    end

    it "fails if the required inputs are not supplied" do
      expect(CompletionHandlerInputTest.call).to be_failed
    end
  end
end
