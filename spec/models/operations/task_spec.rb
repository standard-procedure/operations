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
          ends_with :completed
          ends_with :failed
        end

        task = definition.new state: "not valid"
        expect(task).to_not be_valid
        expect(task.errors).to include(:state)
        task.state = "completed"
        task.validate
        expect(task.errors).to_not include(:state)
      end
    end
  end
end
