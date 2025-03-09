require "rails_helper"

module Operations
  RSpec.describe Task, type: :model do
    before { ActiveJob::Base.queue_adapter = :test }

    describe "sub_tasks" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class ParentTaskWithBlock < Operations::Task
        inputs :name
        starts_with :call_sub_task

        action :call_sub_task do
          call SayHello, name: name do |results|
            self.greeting = results[:greeting]
          end
          # State transition defined statically
        end
        goto :done

        result :done do |results|
          inputs :greeting

          results.greeting = greeting
        end
      end

      class ParentTaskWithResults < Operations::Task
        inputs :name
        starts_with :call_sub_task

        action :call_sub_task do
          results = call SayHello, name: name
          self.greeting = results[:greeting]
          # State transition defined statically
        end
        goto :done

        result :done do |results|
          inputs :greeting

          results.greeting = greeting
        end
      end

      class SayHello < Operations::Task
        inputs :name
        starts_with :say_hello

        result :say_hello do |results|
          results.greeting = "Hello, #{name}!"
        end
      end

      class ParentTaskWithErrors < Operations::Task
        inputs :name
        starts_with :this_will_not_work

        action :this_will_not_work do
          call GoBoom, name: name
        end
      end

      class GoBoom < Operations::Task
        inputs :name
        starts_with :boom
        action :boom do
          raise "BOOM"
        end
      end

      class ParentTaskWithBackgroundSubTasks < Operations::Task
        inputs :name
        starts_with :call_sub_task

        action :call_sub_task do
          start SayHello, name: name
          # State transition defined statically
        end
        goto :done

        result :done
      end
      # standard:enable Lint/ConstantDefinitionInBlock

      it "calls the sub task and uses a block to get the results" do
        task = ParentTaskWithBlock.call name: "Alice"
        expect(task.results[:greeting]).to eq "Hello, Alice!"
      end

      it "calls the sub task" do
        task = ParentTaskWithResults.call name: "Alice"
        expect(task.results[:greeting]).to eq "Hello, Alice!"
      end

      it "starts the sub task in the background" do
        expect { ParentTaskWithBackgroundSubTasks.call name: "Alice" }.to have_enqueued_job(Operations::TaskRunnerJob)
      end

      it "raises an error if the sub task fails" do
        expect { ParentTaskWithErrors.call name: "Alice" }.to raise_error(RuntimeError, "BOOM")
      end
    end
  end
end
