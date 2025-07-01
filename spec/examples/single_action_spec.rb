require "rails_helper"

module Examples
  RSpec.describe "Actions", type: :model do
    # standard:disable Lint/ConstantDefinitionInBlock
    class GeneratesGreetingWithThen < Operations::Task
      has_attribute :name, :string
      validates :name, presence: true
      has_attribute :salutation, :string, default: "Hello"
      validates :salutation, presence: true
      has_attribute :greeting, :string

      action :start do
        self.greeting = "#{salutation} #{name}!"
      end.then :done

      result :done
    end

    class GeneratesGreetingWithGoto < Operations::Task
      has_attribute :name, :string
      validates :name, presence: true
      has_attribute :salutation, :string, default: "Hello"
      validates :salutation, presence: true
      has_attribute :greeting, :string

      action :start do
        self.greeting = "#{salutation} #{name}!"
      end
      go_to :done

      result :done
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    {"using .then syntax" => GeneratesGreetingWithThen, "using goto syntax" => GeneratesGreetingWithGoto}.each do |description, klass|
      describe description do
        it "generates the greeting" do
          task = klass.call(name: "World")
          expect(task).to be_completed
          expect(task.greeting).to eq "Hello World!"
        end

        it "allows the salutation to be overidden" do
          task = klass.call(salutation: "Heyup", name: "World")
          expect(task).to be_completed
          expect(task.greeting).to eq "Heyup World!"
        end

        it "requires a first name" do
          expect { klass.call(name: "") }.to raise_error(ActiveRecord::RecordInvalid)
        end

        it "allows `perform_now` to be used instead of `call`" do
          task = klass.call(name: "World")
          expect(task).to be_completed
          expect(task.greeting).to eq "Hello World!"
        end
      end
    end
  end
end
