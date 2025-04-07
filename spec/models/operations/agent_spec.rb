require "rails_helper"

module Operations
  RSpec.describe Agent, type: :model do
    include ActiveSupport::Testing::TimeHelpers
    before { ActiveJob::Base.queue_adapter = :test }

    # standard:disable Lint/ConstantDefinitionInBlock
    class WaitingTest < Agent
      delay 1.minute
      timeout 10.minutes
      starts_with :start

      action :start do
        WaitingTest.stop = false
      end
      go_to :second_action

      action :second_action do
        # do something
      end
      go_to :value_has_been_set?

      wait_until :value_has_been_set? do
        condition { WaitingTest.stop == true }
        go_to :third_action
      end

      action :third_action do
        # do something else
      end
      go_to :done

      result :done

      def self.stop=(value)
        @stop = value
      end

      def self.stop = @stop
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    describe "start" do
      it "sets the wakes_at value" do
        WaitingTest.stop = false
        freeze_time do
          agent = WaitingTest.start
          expect(agent.wakes_at).to eq Time.now + 1.minute
        end
      end

      it "sets the times_out_at value" do
        WaitingTest.stop = false
        freeze_time do
          agent = WaitingTest.start
          expect(agent.times_out_at).to eq Time.now + 10.minutes
        end
      end

      it "runs through one cycle" do
        WaitingTest.stop = false
        task = WaitingTest.start

        expect(task.state).to eq "value_has_been_set?"
        expect(task).to be_waiting
      end
    end

    it "runs through all actions until it comes across a wait handler" do
      WaitingTest.stop = false
      task = WaitingTest.start
      expect(task).to be_waiting
      WaitingTest.stop = true

      task.perform
      expect(task).to be_completed
    end
  end
end
