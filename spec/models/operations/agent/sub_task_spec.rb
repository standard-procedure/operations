require "rails_helper"

RSpec.describe Operations::Agent, type: :model do
  before { ActiveJob::Base.queue_adapter = :test }

  describe "sub tasks" do
    # standard:disable Lint/ConstantDefinitionInBlock
    class SayHelloAgent < Operations::Agent
      delay 10.minutes
      inputs :name
      starts_with :set_counter

      action :set_counter do
        self.counter = 0
      end
      go_to :enough_time_has_passed?

      wait_until :enough_time_has_passed? do
        condition { counter > 0 }
        go_to :say_hello
      end

      result :say_hello do |results|
        results.greeting = "Hello, #{name}!"
      end
    end

    class AgentCallsAgent < Operations::Agent
      inputs :name
      starts_with :call_sub_task

      action :call_sub_task do
        self.hello_agent = start SayHelloAgent, name: name
      end
      go_to :done

      result :done
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    it "starts the agent in the background" do
      agent = AgentCallsAgent.start name: "Alice"
      expect(agent).to be_waiting

      sub_agent = agent.data[:hello_agent]
      expect(sub_agent).to be_waiting
      expect(sub_agent).to be_kind_of SayHelloAgent
      expect(sub_agent.data[:counter]).to eq "Alice"
      expect(sub_agent.data[:name]).to eq "Alice"
    end
  end
end
