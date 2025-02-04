require "rails_helper"

module Operations::Task::StateManagement
  RSpec.describe WaitHandler, type: :model do
    # standard:disable Lint/ConstantDefinitionInBlock
    class InternalWaitHandlerTest < Operations::Task
      starts_with :time_to_stop

      wait_until :time_to_stop do
        condition { InternalWaitHandlerTest.stop == true }
        go_to :done
      end

      result :done

      def self.stop=(value)
        @stop = value
      end

      def self.stop = @stop ||= false
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    it "fails if the task is not in the background" do
      expect { InternalWaitHandlerTest.call }.to raise_error(Operations::CannotWaitInForeground)
    end

    it "waits if the condition is not met" do
      task = InternalWaitHandlerTest.build background: true
      InternalWaitHandlerTest.stop = false

      expect { Operations::TaskRunnerJob.perform_now(task) }.to have_enqueued_job(Operations::TaskRunnerJob)

      expect(task.reload).to be_waiting
      expect(task.state).to eq "time_to_stop"
    end

    it "moves to the next state if the condition is met" do
      task = InternalWaitHandlerTest.build background: true
      InternalWaitHandlerTest.stop = true

      expect { Operations::TaskRunnerJob.perform_now(task) }.to have_enqueued_job(Operations::TaskRunnerJob)

      expect(task.reload).to be_waiting
      expect(task.state).to eq "done"
    end
  end
end
