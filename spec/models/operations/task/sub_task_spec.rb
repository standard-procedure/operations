require "rails_helper"

module Operations
  RSpec.describe Task, type: :model do
    describe "sub_tasks" do
      # standard:disable Lint/ConstantDefinitionInBlock
      class ParentTaskWithBlock < Operations::Task
        inputs :name
        starts_with :call_sub_task

        action :call_sub_task do
          call SayHello, name: name do |results|
            self.greeting = results[:greeting]
          end
        end
        go_to :done

        result :done do |results|
          inputs :greeting

          results.greeting = greeting
        end
      end

      class ParentTaskWithCall < Operations::Task
        inputs :name
        starts_with :call_sub_task

        action :call_sub_task do
          task = call SayHello, name: name
          self.greeting = task.results[:greeting]
        end
        go_to :done

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

      class ParentTaskWithFailures < Operations::Task
        inputs :name
        starts_with :this_will_not_work

        action :this_will_not_work do
          call FailureTask, name: name
        end
      end

      class FailureTask < Operations::Task
        inputs :name
        starts_with :boom
        action :boom do
          fail_with "BOOM"
        end
      end

      # standard:enable Lint/ConstantDefinitionInBlock

      it "calls the sub task and uses a block to get the results" do
        task = ParentTaskWithBlock.call name: "Alice"
        expect(task.results[:greeting]).to eq "Hello, Alice!"
      end

      it "calls the sub task" do
        task = ParentTaskWithCall.call name: "Alice"
        expect(task.results[:greeting]).to eq "Hello, Alice!"
      end

      it "re-raises any errors from the sub-task" do
        expect { ParentTaskWithErrors.call name: "Alice" }.to raise_error(RuntimeError, "BOOM")
      end

      it "raises an error if the sub task fails" do
        expect { ParentTaskWithFailures.call name: "Alice" }.to raise_error(Operations::Failure, "BOOM")
      end
    end
  end
end
