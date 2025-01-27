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
        it "reads and writes the attribute in the data attribute" do
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
          task.save!
          task.reload
          expect(task.value).to eq second
          expect(task.data["value"]).to eq second
          task.value = first
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

      it "reads and writes the attribute" do
        definition = Class.new(Task) do
          data :active, :boolean
        end
        task = definition.create! state: "whatever", active: true
        expect(task.reload).to be_active
        task.update! active: false
        expect(task.reload).to_not be_active
      end
    end

    context "reading and writing model data attributes" do
      it "reads and writes the attribute" do
        alice = User.create! name: "Alice"
        bob = User.create! name: "Bob"
        definition = Class.new(Task) do
          data :value
        end
        task = definition.create! state: "whatever", value: alice
        expect(task.reload.value).to eq alice
        task.update! value: bob
        expect(task.reload.value).to eq bob
      end
    end
  end
end
