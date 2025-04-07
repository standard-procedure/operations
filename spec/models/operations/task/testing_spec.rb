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
      end
      go_to :done

      action :demolish_the_earth do
        fail_with "the earth has been demolished"
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
      end
      go_to :ask_second_question

      action :ask_second_question do
        inputs :second_question

        results = call AnswerQuestion, question: second_question
        self.second_answer = results[:answer]
      end
      go_to :done

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

    class BackgroundParentTaskToBeTested < Operations::Agent
      starts_with :trigger_background_task

      action :trigger_background_task do
        start TaskToBeTested, answer: 42
      end
      go_to :done

      result :done
    end

    class ComplexDecisionsTest < Operations::Task
      inputs :achievements
      starts_with :whos_the_smartest?

      decision :whos_the_smartest? do
        inputs :achievements
        condition { achievements.include? "New York" }
        go_to :humans
        condition { achievements.include? "mucking about in the water" }
        go_to :dolphins
        condition { achievements.include? "multi-dimensional being" }
        go_to :mice
      end

      result :humans
      result :dolphins
      result :mice
    end

    class WaitHandlerTest < Operations::Agent
      inputs :day_of_week
      starts_with :we_know_what_day_it_is

      wait_until :we_know_what_day_it_is do
        condition { [0, 6].include? day_of_week }
        go_to :weekend
        condition { [1, 2, 3, 4, 5].include? day_of_week }
        go_to :weekday
      end

      result :weekend
      result :weekday
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    context "simple decision handlers" do
      it "tests for state changes" do
        TaskToBeTested.handling(:question, answer: 42) do |test|
          expect(test.next_state).to eq :make_a_fjord
        end
      end
      it "tests for state changes with a matcher" do
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
    end

    context "complex decision handlers" do
      it "changes state as expected" do
        ComplexDecisionsTest.handling(:whos_the_smartest?, achievements: ["guns", "the wheel", "New York"]) do |test|
          expect(test).to have_moved_to :humans
        end
        ComplexDecisionsTest.handling(:whos_the_smartest?, achievements: ["mucking about in the water", "having a good time"]) do |test|
          expect(test).to have_moved_to :dolphins
        end
        ComplexDecisionsTest.handling(:whos_the_smartest?, achievements: ["multi-dimensional being", "having a good time"]) do |test|
          expect(test).to have_moved_to :mice
        end
      end

      it "raises a NoDecision exception if no conditions match" do
        expect { ComplexDecisionsTest.handling(:whos_the_smartest?, achievements: ["banging rocks together"]) }.to raise_error(NoDecision)
      end
    end

    context "wait handlers" do
      it "changes state as expected" do
        WaitHandlerTest.handling(:we_know_what_day_it_is, day_of_week: 0, background: true) do |test|
          expect(test).to have_moved_to :weekend
        end
        WaitHandlerTest.handling(:we_know_what_day_it_is, day_of_week: 1, background: true) do |test|
          expect(test).to have_moved_to :weekday
        end
        WaitHandlerTest.handling(:we_know_what_day_it_is, day_of_week: nil, background: true) do |test|
          expect(test).to have_moved_to :we_know_what_day_it_is
        end
      end
    end

    context "action handlers" do
      it "tests for state changes" do
        TaskToBeTested.handling(:make_a_fjord, answer: 42) do |test|
          expect(test.next_state).to eq :done
        end
      end

      it "tests for state changes with a matcher" do
        TaskToBeTested.handling(:make_a_fjord, answer: 42) do |test|
          expect(test).to have_moved_to :done
        end
      end

      it "tests for failures" do
        TaskToBeTested.handling(:demolish_the_earth) do |test|
          expect(test.failure_message).to eq "the earth has been demolished"
        end
      end

      it "tests for failures with a matcher" do
        TaskToBeTested.handling(:demolish_the_earth) do |test|
          expect(test).to have_failed_with "the earth has been demolished"
        end
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

    context "sub-tasks" do
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
end
