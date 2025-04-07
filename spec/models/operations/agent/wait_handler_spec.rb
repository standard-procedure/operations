require "rails_helper"

RSpec.describe Operations::Agent::WaitHandler, type: :model do
  context "with a single condition" do
    # standard:disable Lint/ConstantDefinitionInBlock
    class InternalWaitHandlerTest < Operations::Agent
      starts_with :stop?

      wait_until :stop? do
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

    it "waits if the condition is not met" do
      InternalWaitHandlerTest.stop = false
      task = InternalWaitHandlerTest.start

      task.perform

      expect(task).to be_waiting
      expect(task.state).to eq "stop?"
    end

    it "moves to the next state if the condition is met" do
      InternalWaitHandlerTest.stop = true
      task = InternalWaitHandlerTest.start

      task.perform

      expect(task).to be_completed
      expect(task.state).to eq "done"
    end
  end
end

context "with multiple conditions" do
  # standard:disable Lint/ConstantDefinitionInBlock
  class MultipleWaitHandlerTest < Operations::Agent
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

  it "waits if no conditions are met" do
    task = MultipleWaitHandlerTest.create! state: "choice_has_been_made?"
    MultipleWaitHandlerTest.value = -1

    task.perform

    expect(task).to be_waiting
    expect(task.state).to eq "choice_has_been_made?"
  end

  it "moves to the first state if the first condition is met" do
    task = MultipleWaitHandlerTest.create! state: "choice_has_been_made?"
    MultipleWaitHandlerTest.value = 1

    task.perform

    expect(task).to be_completed
    expect(task.state).to eq "value_is_1"
  end

  it "moves to the second state if the second condition is met" do
    task = MultipleWaitHandlerTest.create! state: "choice_has_been_made?"
    MultipleWaitHandlerTest.value = 2

    task.perform

    expect(task).to be_completed
    expect(task.state).to eq "value_is_2"
  end

  it "moves to the third state if the third condition is met" do
    task = MultipleWaitHandlerTest.create! state: "choice_has_been_made?"
    MultipleWaitHandlerTest.value = 3

    task.perform

    expect(task).to be_completed
    expect(task.state).to eq "value_is_3"
  end
end
