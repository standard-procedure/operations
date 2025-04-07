require "rails_helper"

module Operations
  RSpec.describe Agent, type: :model do
    include ActiveSupport::Testing::TimeHelpers
    before { ActiveJob::Base.queue_adapter = :test }

    # standard:disable Lint/ConstantDefinitionInBlock
    class WaitingTest < Agent
      starts_with :value_has_been_set

      wait_until :value_has_been_set do
        condition { WaitingTest.stop == true }
        go_to :done
      end

      result :done

      def self.stop=(value)
        @stop = value
      end

      def self.stop = @stop ||= false
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    describe "start" do
      it "starts the task in the initial state" do
        task = StartTest.start
        expect(task.state).to eq "initial"
      end

      it "marks the task as 'waiting'" do
        task = StartTest.start
        expect(task).to be_waiting
      end

      it "marks the task as a background task" do
        task = StartTest.start
        expect(task.background?).to be true
      end

      it "knows if it is a zombie" do
        task = nil
        travel_to 10.minutes.ago do
          task = StartTest.start
        end
        expect(task.reload).to be_zombie
        expect(Operations::Task.zombies).to include task
      end

      it "restarts a zombie task" do
        task = nil
        travel_to 10.minutes.ago do
          task = StartTest.start
        end

        expect(task.reload).to be_zombie

        freeze_time do
          expect { task.restart! }.to have_enqueued_job(TaskRunnerJob).at(1.second.from_now)

          expect(task).to_not be_zombie
        end
      end

      it "restarts all zombie tasks" do
        travel_to 10.minutes.ago do
          5.times { |_| StartTest.start }
        end

        expect(Operations::Task.zombies.count).to eq 5

        Operations::Task.restart_zombie_tasks

        expect(Operations::Task.zombies.count).to eq 0
      end

      it "raises an ArgumentError if the required parameters are not provided" do
        expect { InputTest.start(hello: "world") }.to raise_error(ArgumentError)
      end

      it "performs the task later if the required parameters are provided" do
        freeze_time do
          expect { InputTest.start salutation: "Greetings", name: "Alice" }.to have_enqueued_job(TaskRunnerJob).at(1.second.from_now)
        end
      end

      it "sets the task's timeout" do
        freeze_time do
          task = InputTest.start salutation: "Greetings", name: "Alice"

          expect(task.data[:_execution_timeout].to_time).to eq 5.minutes.from_now
        end
      end

      it "performs the task later if optional parameters are provided in addition to the required ones" do
        freeze_time do
          expect { InputTest.start salutation: "Greetings", name: "Alice", suffix: "- lovely to meet you" }.to have_enqueued_job(Operations::TaskRunnerJob).at(1.second.from_now)
        end
      end
    end
  end
end
