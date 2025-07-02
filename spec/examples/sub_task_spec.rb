require "rails_helper"

module Examples
  RSpec.describe "Sub tasks", type: :model do
    # standard:disable Lint/ConstantDefinitionInBlock
    class StartsOtherThingsTask < Operations::Task
      has_attribute :counter, :integer, default: 1
      validates :counter, presence: true, numericality: {only_integer: true, greater_than: 0}

      action :start do
        counter.times { |i| start OtherThingTask, number: i }
      end.then :done

      result :done
    end

    class OtherThingTask < Operations::Task
      has_attribute :number, :integer
      has_attribute :salutation, :string, default: "Hello"
      has_attribute :name, :string, default: "World"
      has_attribute :greeting, :string

      action :start do
        self.greeting = "#{salutation} #{name}!"
      end
      go_to :done

      result :done
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    it "starts sub-tasks" do
      parent_task = StartsOtherThingsTask.call counter: 3

      expect(parent_task).to be_completed
      expect(parent_task.sub_tasks.size).to eq 3
      expect(parent_task.sub_tasks.all? { |st| st.waiting? }).to be true
      expect(parent_task.sub_tasks.all? { |st| st.is_a? OtherThingTask }).to be true
    end
  end
end
