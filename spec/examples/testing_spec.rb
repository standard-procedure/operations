require "rails_helper"

module Examples
  RSpec.describe "Testing", type: :model do
    # standard:disable Lint/ConstantDefinitionInBlock
    class WeekendChecker < Operations::Task
      has_attribute :day_of_week, :string, default: "Monday"
      validates :day_of_week, presence: true
      starts_with :is_it_the_weekend?

      decision :is_it_the_weekend? do
        condition { %w[Saturday Sunday].include? day_of_week }
        if_true :weekend
        if_false :weekday
      end

      result :weekend
      result :weekday
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    it "is the weekend if the day is Saturday" do
      task = WeekendChecker.test :is_it_the_weekend?, day_of_week: "Saturday"

      expect(task).to be_in :weekend
    end

    it "is a weekday if the day is Wednesday" do
      task = WeekendChecker.test :is_it_the_weekend?, day_of_week: "Wednesday"

      expect(task).to be_in :weekday
    end

    it "fails if required data is not supplied" do
      expect { WeekendChecker.test :is_it_the_weekend?, day_of_week: "" }.to raise_error ActiveRecord::RecordInvalid
    end
  end
end
