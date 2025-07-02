require "rails_helper"

RSpec.describe Operations::Task::Plan::InteractionHandler do
  let(:test_class) do
    Class.new do
      attr_accessor :current_state, :test_value, :interaction_called

      def initialize
        @current_state = "waiting"
        @interaction_called = false
      end

      def wake_up!
        @woke_up = true
      end

      def woke_up?
        @woke_up == true
      end

      def to_s
        "TestTask"
      end
    end
  end

  let(:interaction_name) { :test_interaction }
  let(:simple_implementation) { proc { self.interaction_called = true } }

  before do
    allow(Rails.logger).to receive(:debug)
  end

  describe "#initialize" do
    it "creates a method on the target class" do
      test_class_instance = test_class.new
      expect(test_class_instance).not_to respond_to(interaction_name)

      described_class.new(interaction_name, test_class, &simple_implementation)

      expect(test_class_instance).to respond_to(interaction_name)
    end

    it "initializes legal_states as empty array" do
      handler = described_class.new(interaction_name, test_class, &simple_implementation)
      expect(handler.legal_states).to eq []
    end

    it "converts string interaction names to symbols for method creation" do
      described_class.new("string_interaction", test_class, &simple_implementation)
      test_instance = test_class.new
      expect(test_instance).to respond_to(:string_interaction)
    end
  end

  describe "#when" do
    it "sets legal_states from symbols" do
      handler = described_class.new(interaction_name, test_class, &simple_implementation)
      handler.when(:waiting, :processing)
      expect(handler.legal_states).to eq ["waiting", "processing"]
    end

    it "sets legal_states from strings" do
      handler = described_class.new(interaction_name, test_class, &simple_implementation)
      handler.when("waiting", "processing")
      expect(handler.legal_states).to eq ["waiting", "processing"]
    end

    it "freezes the legal_states array" do
      handler = described_class.new(interaction_name, test_class, &simple_implementation)
      handler.when(:waiting)
      expect(handler.legal_states).to be_frozen
    end

    it "overwrites previous legal_states when called multiple times" do
      handler = described_class.new(interaction_name, test_class, &simple_implementation)
      handler.when(:first)
      handler.when(:second, :third)
      expect(handler.legal_states).to eq ["second", "third"]
    end
  end

  describe "dynamically created interaction method" do
    let(:task_instance) { test_class.new }

    context "with no state restrictions" do
      before do
        described_class.new(interaction_name, test_class, &simple_implementation)
      end

      it "executes the implementation block" do
        task_instance.send(interaction_name)
        expect(task_instance.interaction_called).to be true
      end

      it "calls wake_up! after execution" do
        task_instance.send(interaction_name)
        expect(task_instance.woke_up?).to be true
      end

      it "logs debug information" do
        task_instance.send(interaction_name)
        expect(Rails.logger).to have_received(:debug)
      end
    end

    context "with state restrictions" do
      let(:handler) { described_class.new(interaction_name, test_class, &simple_implementation) }

      before do
        handler.when(:waiting, :ready)
      end

      it "allows interaction when in legal state" do
        task_instance.current_state = "waiting"
        expect { task_instance.send(interaction_name) }.not_to raise_error
        expect(task_instance.interaction_called).to be true
      end

      it "allows interaction when in another legal state" do
        task_instance.current_state = "ready"
        expect { task_instance.send(interaction_name) }.not_to raise_error
        expect(task_instance.interaction_called).to be true
      end

      it "raises InvalidState when called from illegal state" do
        task_instance.current_state = "processing"
        expect {
          task_instance.send(interaction_name)
        }.to raise_error(Operations::InvalidState, /cannot be called in processing/)
      end

      it "does not execute implementation when state is invalid" do
        task_instance.current_state = "invalid"
        expect {
          task_instance.send(interaction_name)
        }.to raise_error(Operations::InvalidState)
        expect(task_instance.interaction_called).to be false
      end

      it "does not call wake_up! when state is invalid" do
        task_instance.current_state = "invalid"
        expect {
          task_instance.send(interaction_name)
        }.to raise_error(Operations::InvalidState)
        expect(task_instance.woke_up?).to be_falsy
      end
    end

    context "with arguments" do
      let(:implementation_with_args) do
        proc do |name, age|
          self.test_value = "#{name} is #{age} years old"
        end
      end

      before do
        described_class.new(:update_info, test_class, &implementation_with_args)
      end

      it "passes arguments to the implementation block" do
        task_instance.update_info("Alice", 30)
        expect(task_instance.test_value).to eq "Alice is 30 years old"
      end

      it "handles multiple arguments correctly" do
        implementation = proc do |*args|
          self.test_value = args.join("-")
        end
        described_class.new(:multi_args, test_class, &implementation)

        task_instance.multi_args("a", "b", "c")
        expect(task_instance.test_value).to eq "a-b-c"
      end
    end

    context "when implementation raises an error" do
      let(:error_implementation) { proc { raise StandardError, "implementation error" } }

      before do
        described_class.new(:error_interaction, test_class, &error_implementation)
      end

      it "propagates the error" do
        expect {
          task_instance.error_interaction
        }.to raise_error(StandardError, "implementation error")
      end

      it "does not call wake_up! when implementation fails" do
        expect {
          task_instance.error_interaction
        }.to raise_error(StandardError)
        expect(task_instance.woke_up?).to be_falsy
      end
    end
  end

  describe "multiple interactions on same class" do
    let(:first_implementation) { proc { self.test_value = "first" } }
    let(:second_implementation) { proc { self.test_value = "second" } }

    it "creates multiple methods on the same class" do
      described_class.new(:first_action, test_class, &first_implementation)
      described_class.new(:second_action, test_class, &second_implementation)

      task_instance = test_class.new
      expect(task_instance).to respond_to(:first_action)
      expect(task_instance).to respond_to(:second_action)

      task_instance.first_action
      expect(task_instance.test_value).to eq "first"

      task_instance.second_action
      expect(task_instance.test_value).to eq "second"
    end

    it "allows different state restrictions for different interactions" do
      first_handler = described_class.new(:restricted_action, test_class, &first_implementation)
      first_handler.when(:waiting)

      described_class.new(:unrestricted_action, test_class, &second_implementation)

      task_instance = test_class.new
      task_instance.current_state = "processing"

      # Restricted action should fail
      expect {
        task_instance.restricted_action
      }.to raise_error(Operations::InvalidState)

      # Unrestricted action should work
      expect { task_instance.unrestricted_action }.not_to raise_error
      expect(task_instance.test_value).to eq "second"
    end
  end

  describe "integration with task class structure" do
    # standard:disable Lint/ConstantDefinitionInBlock
    class InteractionTestTask
      attr_accessor :current_state, :name, :email, :processed

      def initialize
        @current_state = "waiting_for_info"
        @processed = false
      end

      def wake_up!
        @woke_up = true
      end

      def woke_up?
        @woke_up == true
      end

      def to_s
        "InteractionTestTask"
      end
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    it "creates working interaction methods on a task-like class" do
      # Create an interaction that updates user info
      update_handler = described_class.new(:update_user_info, InteractionTestTask) do |name, email|
        self.name = name
        self.email = email
        self.processed = true
      end
      update_handler.when(:waiting_for_info, :ready_for_update)

      task = InteractionTestTask.new

      # Should work when in legal state
      task.update_user_info("John Doe", "john@example.com")
      expect(task.name).to eq "John Doe"
      expect(task.email).to eq "john@example.com"
      expect(task.processed).to be true
      expect(task.woke_up?).to be true
    end

    it "prevents interaction when task is in wrong state" do
      submit_handler = described_class.new(:submit, InteractionTestTask) do
        self.processed = true
      end
      submit_handler.when(:ready_to_submit)

      task = InteractionTestTask.new
      task.current_state = "waiting_for_info"

      expect {
        task.submit
      }.to raise_error(Operations::InvalidState, /cannot be called in waiting_for_info/)
      expect(task.processed).to be false
    end
  end
end
