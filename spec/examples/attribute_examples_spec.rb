require "rails_helper"

module Examples
  RSpec.describe "Attributes Examples", type: :model do
    # standard:disable Lint/ConstantDefinitionInBlock
    class AttributesSpec < Operations::Task
      inputs :first_name, :salutation
      optional :greeting
      starts_with :generate_greeting

      action :generate_greeting do
        self.greeting = "#{salutation} #{first_name}!"
      end
      go_to :done

      result :done
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    it "requires a first name and salutation" do
      expect { AttributesSpec.call }.to raise_error ArgumentError
    end

    it "accesses the mandatory and optional inputs as attributes on the task" do
      @task = AttributesSpec.call first_name: "Alice", salutation: "Hello"

      expect(@task.first_name).to eq "Alice"
      expect(@task.salutation).to eq "Hello"
      expect(@task.greeting).to eq "Hello Alice!"

      @task.salutation = "Heyup"
      expect(@task.salutation).to eq "Heyup"
    end
  end
end
