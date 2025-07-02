require "rails_helper"

module Examples
  RSpec.describe "Indexing", type: :model do
    # standard:disable Lint/ConstantDefinitionInBlock
    class IndexesModelsTask < Operations::Task
      has_model :user, "User"
      validates :user, presence: true
      has_models :documents, "Document"
      has_attribute :count, :integer, default: 0
      index :user, :documents

      action :start do
        self.count = documents.count
      end.then :done

      result :done
    end

    class RemovesIndexedModelTask < Operations::Task
      has_models :documents, "Document"
      index :documents

      action :start do
        self.documents = [documents.first]
      end.then :done

      result :done
    end

    class NoIndexModelsTask < Operations::Task
      has_model :user, "User"
      validates :user, presence: true
      has_models :documents, "Document"
      has_attribute :count, :integer, default: 0

      action :start do
        self.count = documents.count
      end.then :done

      result :done
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    it "records which models it is associated with" do
      user = User.create name: "Alice"
      documents = (1..3).collect { |i| Document.create(filename: "#{i}.txt") }
      task = IndexesModelsTask.call user: user, documents: documents

      expect(task.participants.size).to eq 4

      expect(user.operations).to include(task)
      expect(user.operations_as(:user)).to include(task)
      expect(user.operations_as(:document)).to be_empty
      documents.each do |document|
        expect(document.operations).to include(task)
        expect(document.operations_as(:documents)).to include(task)
        expect(document.operations_as(:user)).to be_empty
      end
    end

    it "removes indexes for models which are no longer involved in the task" do
      documents = (1..3).collect { |i| Document.create(filename: "#{i}.txt") }
      task = RemovesIndexedModelTask.call documents: documents

      expect(task.participants.size).to eq 1

      expect(documents.first.operations).to include task
      expect(documents.second.operations).to be_empty
      expect(documents.third.operations).to be_empty
    end

    it "does not index models if none are defined" do
      user = User.create name: "Alice"
      documents = (1..3).collect { |i| Document.create(filename: "#{i}.txt") }
      task = NoIndexModelsTask.call user: user, documents: documents

      expect(task.participants).to be_empty

      expect(user.operations).to be_empty
      expect(user.operations_as(:user)).to be_empty
      expect(user.operations_as(:document)).to be_empty
      documents.each do |document|
        expect(document.operations).to be_empty
        expect(document.operations_as(:documents)).to be_empty
        expect(document.operations_as(:user)).to be_empty
      end
    end
  end
end
