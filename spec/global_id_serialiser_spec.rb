require "rails_helper"

RSpec.describe GlobalIdSerialiser do
  describe "serialising" do
    it "converts a Hash into JSON" do
      hash = {hello: "world", number: 123, active: false}

      json = described_class.dump(hash)

      expect(json).to include '"hello":"world"'
      expect(json).to include '"number":123'
      expect(json).to include '"active":false'
    end

    it "replaces ActiveRecord models with GlobalID strings" do
      db = Fabrik::Database.new
      alice = db.users.create :alice, name: "Alice"
      hash = {hello: "world", number: 123, active: false, user: alice}

      json = described_class.dump(hash)

      expect(json).to include '"hello":"world"'
      expect(json).to include '"number":123'
      expect(json).to include '"active":false'
      expect(json).to include '"user":"gid://test-app/User/1"'
    end
  end

  describe "deserialising" do
    it "converts JSON into a Hash" do
      json = '{"hello":"world","number":123,"active":false}'

      data = described_class.load(json)

      expect(data).to be_a Hash
      expect(data[:hello]).to eq "world"
      expect(data[:number]).to eq 123
      expect(data[:active]).to eq false
    end

    it "replaces GlobalID strings with ActiveRecord models" do
      db = Fabrik::Database.new
      alice = db.users.create :alice, name: "Alice"
      json = "{\"hello\":\"world\",\"number\":123,\"active\":false,\"user\":\"#{alice.to_global_id}\"}"

      data = described_class.load(json)

      expect(data).to be_a Hash
      expect(data[:hello]).to eq "world"
      expect(data[:number]).to eq 123
      expect(data[:active]).to eq false
      expect(data[:user]).to eq alice
    end

    it "handles errors" do
      db = Fabrik::Database.new
      alice = db.users.create :alice, name: "Alice"
      json = "{\"hello\":\"world\",\"number\":123,\"active\":false,\"user\":\"#{alice.to_global_id}\"}"
      alice.destroy

      data = described_class.load(json)

      expect(data).to be_a Hash
      expect(data[:hello]).to eq "world"
      expect(data[:number]).to eq 123
      expect(data[:active]).to eq false
      expect(data[:user]).to be_nil
    end
  end
end
