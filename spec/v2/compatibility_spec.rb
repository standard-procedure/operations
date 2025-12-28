require_relative "v2_spec_helper"

# Compatibility Suite for Operations V2
# Tests the reference implementation (Memory storage + Inline executor)
# against the complete V2 DSL specification
RSpec.describe "Operations V2 Compatibility Suite" do
  describe "Memory Storage + Inline Executor" do
    let(:storage) { Operations::V2::Adapters::Storage::Memory.new }
    let(:executor) { Operations::V2::Adapters::Executor::Inline.new }

    # Test Task DSL compatibility
    include_examples "Operations V2 Task DSL"

    # Test Storage Adapter contract
    include_examples "Operations V2 Storage Adapter"

    # Test Executor Adapter contract
    include_examples "Operations V2 Executor Adapter"
  end
end
