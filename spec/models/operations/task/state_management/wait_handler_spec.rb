require "rails_helper"

module Operations::Task::StateManagement
  RSpec.describe WaitHandler, type: :model do
    before { ActiveJob::Base.queue_adapter = :test }

    context "with a single condition" do
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

  context "with multiple conditions" do
    # standard:disable Lint/ConstantDefinitionInBlock
    class MultipleWaitHandlerTest < Operations::Task
      starts_with :choice_has_been_made?

      wait_until :choice_has_been_made? do
        condition { MultipleWaitHandlerTest.value == 1 }
        go_to :value_is_1
        condition { MultipleWaitHandlerTest.value == 2 }
        go_to :value_is_2
        condition { MultipleWaitHandlerTest.value == 3 }
        go_to :value_is_3
      end

      result :value_is_1
      result :value_is_2
      result :value_is_3

      def self.value=(value)
        @value = value
      end

      def self.value = @value ||= 0
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    it "fails if the task is not in the background" do
      expect { MultipleWaitHandlerTest.call }.to raise_error(Operations::CannotWaitInForeground)
    end

    it "waits if no conditions are met" do
      task = MultipleWaitHandlerTest.build background: true
      MultipleWaitHandlerTest.value = -1

      expect { Operations::TaskRunnerJob.perform_now(task) }.to have_enqueued_job(Operations::TaskRunnerJob)

      expect(task.reload).to be_waiting
      expect(task.state).to eq "choice_has_been_made?"
    end

    it "moves to the first state if the first condition is met" do
      task = MultipleWaitHandlerTest.build background: true
      MultipleWaitHandlerTest.value = 1

      expect { Operations::TaskRunnerJob.perform_now(task) }.to have_enqueued_job(Operations::TaskRunnerJob)

      expect(task.reload).to be_waiting
      expect(task.state).to eq "value_is_1"
    end

    it "moves to the second state if the second condition is met" do
      task = MultipleWaitHandlerTest.build background: true
      MultipleWaitHandlerTest.value = 2

      expect { Operations::TaskRunnerJob.perform_now(task) }.to have_enqueued_job(Operations::TaskRunnerJob)

      expect(task.reload).to be_waiting
      expect(task.state).to eq "value_is_2"
    end

    it "moves to the third state if the third condition is met" do
      task = MultipleWaitHandlerTest.build background: true
      MultipleWaitHandlerTest.value = 3

      expect { Operations::TaskRunnerJob.perform_now(task) }.to have_enqueued_job(Operations::TaskRunnerJob)

      expect(task.reload).to be_waiting
      expect(task.state).to eq "value_is_3"
    end
  end
end
