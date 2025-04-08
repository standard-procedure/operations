require "rails_helper"

RSpec.describe Operations::Agent::InteractionHandler, type: :model do
  # standard:disable Lint/ConstantDefinitionInBlock
  class SimpleInteractionTest < Operations::Agent
    inputs :important_value
    starts_with :prepare

    action :prepare do
      self.hello = "goodbye"
    end
    go_to :interaction_received?

    wait_until :interaction_received? do
      condition { hello == "world" }
      go_to :done
    end

    result :done

    interaction :update_the_agent do |value_to_check, value_to_write|
      raise "BOOM" unless important_value == value_to_check
      self.hello = value_to_write
    end.when :interaction_received?
  end

  class MultiStateInteractionTest < Operations::Agent
    inputs :destination
    starts_with :start

    action :start do
      self.ready_to_finish = false
    end
    go_to :which_state_should_we_move_to?

    decision :which_state_should_we_move_to? do
      condition { destination == "allow" }
      go_to :allow_interaction
      condition { destination == "disallow" }
      go_to :disallow_interaction
    end

    wait_until :allow_interaction do
      condition { ready_to_finish }
      go_to :done
    end

    wait_until :disallow_interaction do
      condition { ready_to_finish }
      go_to :done
    end

    result :done

    interaction :mark_as_done! do
      self.ready_to_finish = true
    end.when :allow_interaction
  end
  # standard:enable Lint/ConstantDefinitionInBlock

  it "runs within the context of the task's data carrier" do
    task = SimpleInteractionTest.start important_value: 42
    expect(task).to be_waiting

    task.update_the_agent(42, "world")

    expect(task.data[:hello]).to eq "world"
  end

  it "tells the task to immediately perform the next state transition" do
    task = SimpleInteractionTest.start important_value: 42
    expect(task).to be_waiting

    task.update_the_agent(42, "world")

    expect(task).to be_completed
  end

  it "records any failures" do
    task = SimpleInteractionTest.start important_value: 101
    expect(task).to be_waiting

    expect { task.update_the_agent(99, "world") }.to raise_error(RuntimeError)

    expect(task).to be_failed
    expect(task.results[:failure_message]).to eq "BOOM"
  end

  it "cannot be triggered unless the task is in a legal state" do
    task = MultiStateInteractionTest.start destination: "disallow"
    expect(task).to be_waiting

    expect { task.mark_as_done! }.to raise_error(Operations::InvalidState)

    expect(task).to be_failed
    expect(task.results[:exception_class]).to eq "Operations::InvalidState"
  end
end
