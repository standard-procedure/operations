require "rails_helper"

module Operations
  RSpec.describe TaskRunnerJob, type: :job do
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
      starts_with :going_wrong

      action :going_wrong do
        fail_with "oops"
      end
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    it "performs waiting tasks" do
      task = InputTest.build(background: true, salutation: "Hello", name: "Alice")

      TaskRunnerJob.perform_now task

      expect(task.reload.results[:greeting]).to eq "Hello Alice"
      expect(task).to be_completed
    end

    it "does not perform in_progress tasks" do
      task = InputTest.build(background: true, salutation: "Hello", name: "Alice")
      task.update! status: "in_progress"

      TaskRunnerJob.perform_now task

      expect(task.reload.results[:greeting]).to be_blank
      expect(task).to be_in_progress
    end

    it "does not perform completed tasks" do
      task = InputTest.build(background: true, salutation: "Hello", name: "World")
      task.update! status: "completed", results: {greeting: "Goodbye Bob"}

      TaskRunnerJob.perform_now task

      expect(task.reload.results[:greeting]).to eq "Goodbye Bob"
      expect(task).to be_completed
    end

    it "does not perform failed tasks" do
      task = InputTest.build(background: true, salutation: "Hello", name: "World")
      task.update! status: "failed", results: {failure_message: "Something went wrong"}

      TaskRunnerJob.perform_now task

      expect(task.reload.results[:greeting]).to be_blank
      expect(task.reload.results[:failure_message]).to eq "Something went wrong"
      expect(task).to be_failed
    end

    it "resumes a task from the state it is currently in and queues a job to move to the next state" do
      task = MultistageTest.build(background: true)
      task.update! status: "waiting", state: "stage_two"

      expect { TaskRunnerJob.perform_now task }.to have_enqueued_job(TaskRunnerJob)

      expect(task.reload.state).to eq "done"
    end

    it "completes a task" do
      task = MultistageTest.build(background: true)
      task.update! status: "waiting", state: "done"

      expect { TaskRunnerJob.perform_now task }.to_not have_enqueued_job(TaskRunnerJob)

      expect(task.reload.state).to eq "done"
      expect(task).to be_completed
    end

    it "does not queue another job if the task fails" do
      task = BackgroundFailureTest.build(background: true)

      expect { TaskRunnerJob.perform_now task }.to_not have_enqueued_job(TaskRunnerJob)

      expect(task.reload).to be_failed
    end
  end
end
