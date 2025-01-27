require "rails_helper"

module Operations
  RSpec.describe Task::Attributes, type: :model do
    [[:string, "Alice", "Bob"], [:integer, 1, 2], [:float, 1.0, 2.0], [:datetime, Time.now, Time.now + 1.hour]].each do |type, first, second|
      context "configuring #{type} data-attributes" do
        it "declares the attribute" do
          definition = Class.new(Task) do
            data :value, type
          end
          expect(definition.attribute_types["value"].type).to eq type
        end
      end

      context "reading and writing #{type} data-attributes" do
        it "stores the attribute in the data attribute" do
          definition = Class.new(Task) do
            data :value, type
          end
          task = definition.new state: "whatever", value: first
          expect(task.value).to eq first
          expect(task.data["value"]).to eq first
          task.value = second
          expect(task.value).to eq second
          expect(task.data["value"]).to eq second
          expect(task.will_save_change_to_data?).to be true
        end
      end
    end

    context "configuring boolean data-attributes" do
      it "declares the attribute" do
        definition = Class.new(Task) do
          data :value, :boolean
        end
        expect(definition.attribute_types["value"].type).to eq :boolean
      end

      it "stores the attribute in the data attribute" do
        definition = Class.new(Task) do
          data :enabled, :boolean
        end
        task = definition.new state: "whatever", enabled: true
        expect(task).to be_enabled
        expect(task.data["enabled"]).to be true
        task.enabled = false
        expect(task).to_not be_enabled
        expect(task.data["enabled"]).to be false
      end
    end

    context "reading and writing model data-attributes" do
      it "stores the attribute in the data attribute" do
        alice = User.create! name: "Alice"
        bob = User.create! name: "Bob"
        definition = Class.new(Task) do
          data :value
        end
        task = definition.new state: "whatever", value: alice
        expect(task.value).to eq alice
        task.value = bob
        expect(task.value).to eq bob
      end
    end
  end
end
