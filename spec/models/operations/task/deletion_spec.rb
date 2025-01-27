require "rails_helper"

module Operations
  RSpec.describe Task::Deletion, type: :model do
    describe "configuration" do
      around do |example|
        original = Task.deletes_after
        example.run
        Task.delete_after original
      end

      it "defines a default delete_at value" do
        Task.delete_after 365.days
        expect(Task.deletes_after).to eq 365.days
      end

      it "has a default deletion time of 90 days" do
        expect(Task.deletes_after).to eq 90.days
      end

      it "sets the default delete_at value" do
        Task.delete_after 365.days
        task = Task.new
        expect(task.delete_at).to be_within(1.second).of(365.days.from_now)
      end

      it "must have a delete_at value" do
        task = Task.new delete_at: nil
        expect(task).to_not be_valid
        expect(task.errors).to include(:delete_at)
      end

      # standard:disable Lint/ConstantDefinitionInBlock
      class DeletingTask < Task
        starts_with :initial
        action :initial do
          # nothing
        end
      end
      # standard:enable Lint/ConstantDefinitionInBlock
      it "finds tasks scheduled for deletion" do
        to_delete = DeletingTask.create! state: "initial", delete_at: 1.day.ago
        to_keep = DeletingTask.create! state: "initial", delete_at: 1.day.from_now

        tasks_for_deletion = Task.for_deletion
        expect(tasks_for_deletion).to include(to_delete)
        expect(tasks_for_deletion).to_not include(to_keep)
      end

      it "deletes tasks scheduled for deletion" do
        to_delete = DeletingTask.create! state: "initial", delete_at: 1.day.ago
        to_keep = DeletingTask.create! state: "initial", delete_at: 1.day.from_now

        Task.delete_expired
        tasks = Task.all
        expect(tasks).to_not include(to_delete)
        expect(tasks).to include(to_keep)
      end
    end
  end
end
