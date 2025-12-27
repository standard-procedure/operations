require_relative "../v2_spec_helper"

module V2Examples
  RSpec.describe "Decisions" do
    # standard:disable Lint/ConstantDefinitionInBlock
    class SaysHelloOrGoodbyeWithIf < Operations::V2::Task
      has_attribute :name, :string
      validates :name, presence: true
      has_attribute :arriving, :boolean, default: true
      has_attribute :message, :string
      starts_with :coming_or_going?

      decision :coming_or_going? do
        condition { arriving? }
        if_true :say_hello
        if_false :say_goodbye
      end

      action :say_hello do
        self.message = "Hello #{name}"
      end.then :done

      action :say_goodbye do
        self.message = "Goodbye #{name}"
      end.then :done

      result :done
    end

    class SaysHelloOrGoodbyeWithGoto < Operations::V2::Task
      has_attribute :name, :string
      validates :name, presence: true
      has_attribute :arriving, :boolean, default: true
      has_attribute :message, :string
      starts_with :coming_or_going?

      decision :coming_or_going? do
        condition { arriving? }
        go_to :say_hello
        condition { !arriving? }
        go_to :say_goodbye
      end

      action :say_hello do
        self.message = "Hello #{name}"
      end.then :done

      action :say_goodbye do
        self.message = "Goodbye #{name}"
      end.then :done

      result :done
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    {"with if syntax" => SaysHelloOrGoodbyeWithIf, "with go_to syntax" => SaysHelloOrGoodbyeWithGoto}.each do |description, klass|
      describe description do
        it "says hello if you are arriving" do
          task = klass.call(name: "Alice", arriving: true)

          expect(task).to be_completed
          expect(task.message).to eq "Hello Alice"
        end

        it "says goodbye if you are leaving" do
          task = klass.call(name: "Alice", arriving: false)

          expect(task).to be_completed
          expect(task.message).to eq "Goodbye Alice"
        end
      end
    end
  end
end
