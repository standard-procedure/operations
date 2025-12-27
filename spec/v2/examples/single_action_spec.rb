require_relative "../v2_spec_helper"

module V2Examples
  RSpec.describe "Actions" do
    # standard:disable Lint/ConstantDefinitionInBlock
    class GeneratesGreetingWithThen < Operations::V2::Task
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

    class GeneratesGreetingWithGoto < Operations::V2::Task
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

        it "allows the salutation to be overridden" do
          task = klass.call(salutation: "Heyup", name: "World")
          expect(task).to be_completed
          expect(task.greeting).to eq "Heyup World!"
        end

        it "requires a name" do
          expect { klass.call(name: "") }.to raise_error(Operations::V2::ValidationError)
        end

        it "allows `perform_now` to be used instead of `call`" do
          task = klass.perform_now(name: "World")
          expect(task).to be_completed
          expect(task.greeting).to eq "Hello World!"
        end
      end
    end
  end
end
