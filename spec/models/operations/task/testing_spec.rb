require "rails_helper"

module Operations
  RSpec.describe Operations::Task::Testing, type: :model do
    # standard:disable Lint/ConstantDefinitionInBlock
    class TaskToBeTested < Operations::Task
      inputs :answer
      starts_with :question

      decision :question do
        condition { answer == 42 }
        if_true :make_a_fjord
        if_false { fail_with "the earth has been demolished" }
      end

      action :make_a_fjord do
        self.coastline = "long and winding"
        go_to :done
      end

      result :done do |results|
        results.reverse = coastline.reverse
      end
    end

    class TaskToBeTestedWithMethods < Operations::Task
      inputs :answer
      starts_with :question

      decision :question do
        if_true :make_a_fjord
        if_false { fail_with "the earth has been demolished" }
      end

      def question(data) = (data.answer == 42)

      action :make_a_fjord

      def make_a_fjord(data)
        data.coastline = "long and winding"
        go_to :done
      end

      result :done do |results|
        results.reverse = coastline.reverse
      end
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    context "when handlers are defined as blocks" do
      it "tests for state changes" do
        TaskToBeTested.handling(:question, answer: 42) do |test|
          expect(test.next_state).to eq :make_a_fjord
        end
      end

      it "tests for state changes using a matcher" do
        TaskToBeTested.handling(:question, answer: 42) do |test|
          expect(test).to have_moved_to :make_a_fjord
        end
      end

      it "tests for failures" do
        TaskToBeTested.handling(:question, answer: 99) do |test|
          expect(test.failure_message).to eq "the earth has been demolished"
        end
      end

      it "tests for failures using a matcher" do
        TaskToBeTested.handling(:question, answer: 99) do |test|
          expect(test).to have_failed_with "the earth has been demolished"
        end
      end

      it "tests for existing data" do
        TaskToBeTested.handling(:question, answer: 42) do |test|
          expect(test.answer).to eq 42
        end
      end

      it "tests for new data" do
        TaskToBeTested.handling(:make_a_fjord, answer: 42) do |test|
          expect(test.coastline).to eq "long and winding"
        end
      end

      it "tests results" do
        TaskToBeTested.handling(:done, answer: 42, coastline: "long and winding") do |test|
          expect(test.reverse).to eq "gnidniw dna gnol"
        end
      end
    end

    context "when handlers are defined as methods" do
      it "tests for state changes" do
        TaskToBeTestedWithMethods.handling(:question, answer: 42) do |test|
          expect(test.next_state).to eq :make_a_fjord
        end
      end

      it "tests for state changes using a matcher" do
        TaskToBeTestedWithMethods.handling(:question, answer: 42) do |test|
          expect(test).to have_moved_to :make_a_fjord
        end
      end

      it "tests for failures" do
        TaskToBeTestedWithMethods.handling(:question, answer: 99) do |test|
          expect(test.failure_message).to eq "the earth has been demolished"
        end
      end

      it "tests for failures using a matcher" do
        TaskToBeTestedWithMethods.handling(:question, answer: 99) do |test|
          expect(test).to have_failed_with "the earth has been demolished"
        end
      end

      it "tests for existing data" do
        TaskToBeTestedWithMethods.handling(:question, answer: 42) do |test|
          expect(test.answer).to eq 42
        end
      end

      it "tests for new data" do
        TaskToBeTestedWithMethods.handling(:make_a_fjord, answer: 42) do |test|
          expect(test.coastline).to eq "long and winding"
        end
      end

      it "tests results" do
        TaskToBeTestedWithMethods.handling(:done, answer: 42, coastline: "long and winding") do |test|
          expect(test.reverse).to eq "gnidniw dna gnol"
        end
      end
    end
  end
end
