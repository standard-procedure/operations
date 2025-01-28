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
    # standard:enable Lint/ConstantDefinitionInBlock

    it "records the result" do
      task = CompletionHandlerTest.call
      expect(task.results).to eq(hello: "world")
      expect(task).to be_completed
    end
  end
end
