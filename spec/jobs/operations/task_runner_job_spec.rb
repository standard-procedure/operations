require "rails_helper"

module Operations
  RSpec.describe TaskRunnerJob, type: :job do
    include ActiveSupport::Testing::TimeHelpers
    before { ActiveJob::Base.queue_adapter = :test }

    # standard:disable Lint/ConstantDefinitionInBlock
    class InputTest < Task
      inputs :salutation, :name
      starts_with :generate_greeting
      result :generate_greeting do |results|
        results.greeting = [salutation, name, suffix].compact.join(" ")
      end
    end

    class MultistageTest < Task
      starts_with :stage_one

      action :stage_one do
        go_to :stage_two
      end

      action :stage_two do
        go_to :done
      end

      result :done
    end

    class BackgroundFailureTest < Task
      delay 10.seconds
      timeout 1.minute

      starts_with :going_wrong

      action :going_wrong do
        fail_with "oops"
      end
    end

    class TimeoutHandlerTest < Task
      delay 10.seconds
      timeout 1.minute

      starts_with :doing_stuff

      action :doing_stuff do
        # do something
      end

      on_timeout do
        TimeoutHandlerTest.message = "timeout"
      end

      def self.message=(value)
        @message = value
      end

      def self.message = @message ||= ""
    end

    # standard:enable Lint/ConstantDefinitionInBlock

    it "performs waiting tasks" do
      task = InputTest.build(background: true, salutation: "Hello", name: "Alice")

      TaskRunnerJob.perform_now task

      expect(task.reload).to be_completed
      expect(task.results[:greeting]).to eq "Hello Alice"
    end

    it "does not perform in_progress tasks" do
      task = InputTest.build(background: true, salutation: "Hello", name: "Alice")
      task.update! status: "in_progress"

      TaskRunnerJob.perform_now task

      expect(task.reload).to be_in_progress
      expect(task.results[:greeting]).to be_blank
    end

    it "does not perform completed tasks" do
      task = InputTest.build(background: true, salutation: "Hello", name: "World")
      task.update! status: "completed", results: {greeting: "Goodbye Bob"}

      TaskRunnerJob.perform_now task

      expect(task.reload).to be_completed
      expect(task.results[:greeting]).to eq "Goodbye Bob"
    end

    it "does not perform failed tasks" do
      task = InputTest.build(background: true, salutation: "Hello", name: "World")
      task.update! status: "failed", results: {failure_message: "Something went wrong"}

      TaskRunnerJob.perform_now task

      expect(task.reload).to be_failed
      expect(task.results[:greeting]).to be_blank
      expect(task.results[:failure_message]).to eq "Something went wrong"
    end

    it "resumes a task from the state it is currently in and queues a job to move to the next state" do
      task = MultistageTest.build(background: true)
      task.update! status: "waiting", state: "stage_two"

      expect { TaskRunnerJob.perform_now task }.to have_enqueued_job(TaskRunnerJob)

      expect(task.reload).to be_waiting
      expect(task.state).to eq "done"
    end

    it "completes a task" do
      task = MultistageTest.build(background: true)
      task.update! status: "waiting", state: "done"

      expect { TaskRunnerJob.perform_now task }.to_not have_enqueued_job(TaskRunnerJob)

      expect(task.reload).to be_completed
      expect(task.state).to eq "done"
    end

    it "does not queue another job if the task fails" do
      task = BackgroundFailureTest.build(background: true)

      expect { TaskRunnerJob.perform_now task }.to_not have_enqueued_job(TaskRunnerJob)

      expect(task.reload).to be_failed
    end

    it "fails a task if the timeout has expired" do
      freeze_time do
        task = InputTest.build(background: true, _execution_timeout: 1.second.ago, salutation: "Hello", name: "Alice")

        expect { TaskRunnerJob.perform_now task }.to_not have_enqueued_job(TaskRunnerJob)

        expect(task.reload).to be_failed
        expect(task.results[:failure_message]).to eq "Timeout expired"
      end
    end
  end
end
