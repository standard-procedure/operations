require "rails_helper"

module Operations
  RSpec.describe Agent do
    describe "plan" do
      it "has a default delay of 5 minutes" do
        expect(Operations::Agent.background_delay).to eq 5.minutes
      end

      it "can set the delay" do
        definition = Class.new(Agent) do
          delay 10.minutes
        end
        expect(definition.background_delay).to eq 10.minutes
      end

      it "has a default timeout of 24 hours" do
        expect(Agent.execution_timeout).to eq 24.hours
      end

      it "can set the timeout" do
        definition = Class.new(Agent) do
          timeout 1.week
        end
        expect(definition.execution_timeout).to eq 1.week
      end

      it "defines a wait handler" do
        definition = Class.new(Agent) do
          wait_until :something_has_happened? do
            # whatever
          end
        end

        handler = definition.handler_for(:something_has_happened?)
        expect(handler).to_not be_nil
        expect(handler).to be_kind_of Operations::Agent::WaitHandler
      end
    end
  end
end
