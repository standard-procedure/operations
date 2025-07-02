require "rails_helper"

RSpec.describe Operations::Task::Plan::ResultHandler do
  let(:result_name) { :test_result }
  let(:handler) { described_class.new(result_name) }

  describe "#immediate?" do
    it "returns true" do
      expect(handler.immediate?).to be true
    end
  end

  describe "#call" do
    let(:task_class) do
      Class.new do
        attr_accessor :task_status, :completed_at

        def update(attributes)
          attributes.each { |key, value| send("#{key}=", value) }
        end
      end
    end

    let(:task) { task_class.new }

    it "updates task status to completed" do
      handler.call(task)
      expect(task.task_status).to eq "completed"
    end

    it "sets completed_at to current time" do
      time_before = Time.current
      handler.call(task)
      expect(task.completed_at).to be >= time_before
      expect(task.completed_at).to be <= Time.current
    end

    it "updates both task_status and completed_at in one call" do
      expect(task).to receive(:update).with(
        task_status: "completed",
        completed_at: kind_of(Time)
      )
      handler.call(task)
    end

    context "when task update fails" do
      let(:failing_task) do
        Class.new do
          def update(attributes)
            raise StandardError, "Update failed"
          end
        end.new
      end

      it "propagates the error" do
        expect { handler.call(failing_task) }.to raise_error(StandardError, "Update failed")
      end
    end
  end

  describe "integration with task workflow" do
    # standard:disable Lint/ConstantDefinitionInBlock
    class ResultHandlerTestTask < Operations::Task
      has_attribute :message, :string

      action :start do
        self.message = "Task executed successfully"
      end.then :finished

      result :finished
    end

    class MultipleResultsTestTask < Operations::Task
      has_attribute :path_taken, :string
      has_attribute :success, :boolean, default: true
      starts_with :check_condition

      decision :check_condition do
        condition { success }
        if_true :success_result
        if_false :failure_result
      end

      result :success_result
      result :failure_result
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    it "completes task when result state is reached" do
      task = ResultHandlerTestTask.call
      expect(task).to be_completed
      expect(task.completed_at).to be_present
      expect(task.task_status).to eq "completed"
      expect(task.message).to eq "Task executed successfully"
    end

    it "works with multiple result states" do
      success_task = MultipleResultsTestTask.call(success: true)
      expect(success_task).to be_completed
      expect(success_task.task_status).to eq "completed"

      failure_task = MultipleResultsTestTask.call(success: false)
      expect(failure_task).to be_completed
      expect(failure_task.task_status).to eq "completed"
    end

    it "sets completion timestamp when task reaches result" do
      time_before = Time.current
      task = ResultHandlerTestTask.call
      expect(task.completed_at).to be >= time_before
      expect(task.completed_at).to be <= Time.current
    end
  end
end
