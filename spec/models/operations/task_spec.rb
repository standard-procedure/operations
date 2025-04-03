require "rails_helper"

module Operations
  RSpec.describe Task, type: :model do
    include ActiveSupport::Testing::TimeHelpers
    before { ActiveJob::Base.queue_adapter = :test }

    describe "configuration" do
      it "declares which parameters are required" do
        definition = Class.new(Task) do
          inputs :first_name, :last_name
        end

        expect(definition.required_inputs).to include :first_name
        expect(definition.required_inputs).to include :last_name
      end

      it "declares which parameters are optional" do
        definition = Class.new(Task) do
          optional :middle_name
        end

        expect(definition.optional_inputs).to include :middle_name
      end

      it "declares the initial state" do
        definition = Class.new(Task) do
          starts_with "you_are_here"
        end
        expect(definition.initial_state).to eq :you_are_here
      end

      it "declares a decision handler" do
        definition = Class.new(Task) do
          decision :is_it_done? do
            condition { rand(2) == 0 }
            if_true :done
            if_false :not_done
          end
        end

        handler = definition.handler_for(:is_it_done?)
        expect(handler).to_not be_nil
      end

      it "declares an action handler" do
        definition = Class.new(Task) do
          action :do_something do
            # whatever
            go_to :i_did_it
          end
        end

        handler = definition.handler_for(:do_something)
        expect(handler).to_not be_nil
      end

      it "declares a completed handler" do
        definition = Class.new(Task) do
          result :all_done do |results|
            results[:job] = "done"
          end
        end

        handler = definition.handler_for(:all_done)
        expect(handler).to_not be_nil
      end
    end

    describe "state" do
      it "must be one of the defined states" do
        definition = Class.new(Task) do
          starts_with :authorised?
          decision :authorised? do
            condition { true }
            if_true :completed
            if_false :failed
          end
          result :completed
          result :failed
        end

        task = definition.new state: "not valid"
        expect(task).to_not be_valid
        expect(task.errors).to include(:state)
        task.state = "completed"
        task.validate
        expect(task.errors).to_not include(:state)
      end
    end

    describe "status" do
      it "defaults to 'in_progress'" do
        task = Task.new
        expect(task).to be_in_progress
      end

      # standard:disable Lint/ConstantDefinitionInBlock
      class CompletedStateTest < Task
        starts_with "go"
        action "go" do
          # Do something
        end
        go_to :done

        result "done" do |results|
          results.hello = "world"
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      it "is completed after a result is set" do
        task = CompletedStateTest.call
        expect(task).to be_completed
        expect(task.state).to eq "done"
        expect(task.results[:hello]).to eq "world"
      end

      it "stores the results in the database after completion" do
        task = CompletedStateTest.call
        expect(task).to be_completed
        id = task.id
        copy = Task.find(id)

        expect(copy.results[:hello]).to eq "world"
      end

      # standard:disable Lint/ConstantDefinitionInBlock
      class FailureTest < Task
        starts_with "go"
        action "go" do |_|
          fail_with "BOOM"
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      it "raises a Failure if a failure is declared" do
        expect { FailureTest.call }.to raise_error(Operations::Failure)
      end

      it "stores the results in the database after failure" do
        expect { FailureTest.call }.to raise_error(Operations::Failure)

        task = FailureTest.last
        expect(task.results[:failure_message]).to eq "BOOM"
      end
    end

    # standard:disable Lint/ConstantDefinitionInBlock
    class StartTest < Task
      starts_with "initial"

      action "initial" do
        # nothing
      end
    end

    class InputTest < Task
      inputs :salutation, :name
      starts_with :generate_greeting
      result :generate_greeting do |results|
        results.name = name
        results.greeting = [salutation, name, suffix].compact.join(" ")
      end
    end

    class WaitingTest < Task
      starts_with :value_has_been_set

      wait_until :value_has_been_set do
        condition { WaitingTest.stop == true }
        go_to :done
      end

      result :done

      def self.stop=(value)
        @stop = value
      end

      def self.stop = @stop ||= false
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    describe "call" do
      it "creates the task in the initial state" do
        task = StartTest.call
        expect(task.state).to eq "initial"
      end

      it "marks the task as 'in progress'" do
        task = StartTest.call
        expect(task).to be_in_progress
      end

      it "marks the task as a foreground task" do
        task = StartTest.call
        expect(task.background?).to be false
      end

      it "raises an ArgumentError if the required parameters are not provided" do
        expect { InputTest.call(hello: "world") }.to raise_error(ArgumentError)
      end

      it "performs the task if the required parameters are provided" do
        task = InputTest.call salutation: "Greetings", name: "Alice"
        expect(task.results[:greeting]).to eq "Greetings Alice"
      end

      it "performs the task if optional parameters are provided in addition to the required ones" do
        task = InputTest.call salutation: "Greetings", name: "Alice", suffix: "- lovely to meet you"
        expect(task.results[:greeting]).to eq "Greetings Alice - lovely to meet you"
      end

      it "raises an Operations::CannotWaitInForeground error if the task is not a background task" do
        expect { WaitingTest.call }.to raise_error(Operations::CannotWaitInForeground)
      end
    end

    describe "start" do
      it "starts the task in the initial state" do
        task = StartTest.start
        expect(task.state).to eq "initial"
      end

      it "marks the task as 'waiting'" do
        task = StartTest.start
        expect(task).to be_waiting
      end

      it "marks the task as a background task" do
        task = StartTest.start
        expect(task.background?).to be true
      end

      it "knows if it is a zombie" do
        task = nil
        travel_to 10.minutes.ago do
          task = StartTest.start
        end
        expect(task.reload).to be_zombie
        expect(Operations::Task.zombies).to include task
      end

      it "restarts a zombie task" do
        task = nil
        travel_to 10.minutes.ago do
          task = StartTest.start
        end

        expect(task.reload).to be_zombie

        freeze_time do
          expect { task.restart! }.to have_enqueued_job(TaskRunnerJob).at(1.second.from_now)

          expect(task).to_not be_zombie
        end
      end

      it "raises an ArgumentError if the required parameters are not provided" do
        expect { InputTest.start(hello: "world") }.to raise_error(ArgumentError)
      end

      it "performs the task later if the required parameters are provided" do
        freeze_time do
          expect { InputTest.start salutation: "Greetings", name: "Alice" }.to have_enqueued_job(TaskRunnerJob).at(1.second.from_now)
        end
      end

      it "sets the task's timeout" do
        freeze_time do
          task = InputTest.start salutation: "Greetings", name: "Alice"

          expect(task.data[:_execution_timeout].to_time).to eq 5.minutes.from_now
        end
      end

      it "performs the task later if optional parameters are provided in addition to the required ones" do
        freeze_time do
          expect { InputTest.start salutation: "Greetings", name: "Alice", suffix: "- lovely to meet you" }.to have_enqueued_job(Operations::TaskRunnerJob).at(1.second.from_now)
        end
      end
    end

    describe "handling exceptions" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class ExceptionTest < Operations::Task
        class MyException < StandardError; end
        inputs :take_a_risk
        starts_with :choose_where_to_go

        decision :choose_where_to_go do
          condition { take_a_risk == "some_risky_decision" }
          go_to :some_risky_decision
          condition { take_a_risk == "some_risky_action" }
          go_to :some_risky_action
          condition { take_a_risk == "some_risky_result" }
          go_to :some_risky_result
        end

        decision :some_risky_decision do
          condition { raise MyException.new("BOOM") }
          if_true :some_risky_action
          if_false :some_risky_result
        end

        action :some_risky_action do |_|
          raise MyException.new("BOOM")
        end

        result :some_risky_result do |_|
          raise MyException.new("BOOM")
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock
      context "in actions" do
        it "raises the exception" do
          expect { ExceptionTest.call take_a_risk: "some_risky_action" }.to raise_error(ExceptionTest::MyException)
        end
      end

      context "in decisions" do
        it "raises the exception" do
          expect { ExceptionTest.call take_a_risk: "some_risky_decision" }.to raise_error(ExceptionTest::MyException)
        end
      end

      context "in results" do
        it "raises the exception" do
          expect { ExceptionTest.call take_a_risk: "some_risky_result" }.to raise_error(ExceptionTest::MyException)
        end
      end
    end

    describe "serialisation" do
      it "stores primitive data in the data field" do
        @task = InputTest.call salutation: "Hello", name: "Alice"

        expect(@task.data[:salutation]).to eq "Hello"
        expect(@task.data[:name]).to eq "Alice"
      end

      it "stores models in the data field with an index" do
        @db = Fabrik::Database.new
        @alice = @db.users.create :alice, name: "Alice"

        @task = InputTest.call salutation: "Hello", name: @alice

        expect(@task.data[:salutation]).to eq "Hello"
        expect(@task.data[:name]).to eq @alice
        expect(@task.task_participants.in(:data).size).to eq 1
        expect(@task.task_participants.in(:data).first.participant).to eq @alice
      end

      it "stores primitive data in the results field" do
        @task = InputTest.call salutation: "Hello", name: "Alice"

        expect(@task.results[:name]).to eq "Alice"
      end

      it "stores models in the results field with an index" do
        @db = Fabrik::Database.new
        @alice = @db.users.create :alice, name: "Alice"

        @task = InputTest.call salutation: "Hello", name: @alice

        expect(@task.results[:name]).to eq @alice
        expect(@task.task_participants.in(:results).size).to eq 1
        expect(@task.task_participants.in(:results).first.participant).to eq @alice
      end
    end
  end
end
