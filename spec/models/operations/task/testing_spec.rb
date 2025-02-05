require "rails_helper"

module Operations
  RSpec.describe Operations::Task::Testing, type: :model do
    # standard:disable Lint/ConstantDefinitionInBlock
    class TaskToBeTested < Operations::Task
      inputs :answer
      starts_with :question

      decision :question do
        inputs :answer
        optional :something_else

        condition { answer == 42 }
        if_true :make_a_fjord
        if_false { fail_with "the earth has been demolished" }
      end

      action :make_a_fjord do
        inputs :answer
        optional :something_else

        self.coastline = "long and winding"
        go_to :done
      end

      result :done do |results|
        inputs :coastline
        optional :something_else

        results.reverse = coastline.reverse
      end
    end

    class ParentTaskToBeTested < Operations::Task
      inputs :first_question, :second_question
      starts_with :ask_first_question

      action :ask_first_question do
        inputs :first_question

        results = call AnswerQuestion, question: first_question
        self.first_answer = results[:answer]
        go_to :ask_second_question
      end

      action :ask_second_question do
        inputs :second_question

        results = call AnswerQuestion, question: second_question
        self.second_answer = results[:answer]
        go_to :done
      end

      result :done do |results|
        inputs :first_answer, :second_answer

        results.first_answer = first_answer
        results.second_answer = second_answer
      end
    end

    class AnswerQuestion < Operations::Task
      inputs :question
      starts_with :get_answer

      result :get_answer do |results|
        inputs :question

        results.answer = 42
      end
    end

    class BackgroundParentTaskToBeTested < Operations::Task
      starts_with :trigger_background_task

      action :trigger_background_task do
        start TaskToBeTested, answer: 42
        go_to :done
      end

      result :done
    end
    # standard:enable Lint/ConstantDefinitionInBlock

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

    it "tests that the parent task calls the sub task" do
      ParentTaskToBeTested.handling(:ask_first_question, first_question: "What is the answer to life, the universe, and everything?") do |test|
        expect(test.sub_tasks).to include AnswerQuestion
      end
    end

    it "tests that the parent task starts the sub task in the background" do
      BackgroundParentTaskToBeTested.handling(:trigger_background_task) do |test|
        expect(test.sub_tasks).to include TaskToBeTested
      end
    end
  end
end
