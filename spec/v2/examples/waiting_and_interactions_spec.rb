require_relative "../v2_spec_helper"

module V2Examples
  RSpec.describe "Waiting and Interactions" do
    # Mock User model for testing
    class User
      attr_accessor :id, :name

      @@users = {}
      @@next_id = 1

      def self.create!(attributes)
        user = new
        user.id = @@next_id
        @@next_id += 1
        user.name = attributes[:name]
        @@users[user.id] = user
        user
      end

      def self.find(id)
        @@users[id]
      end

      def self.reset!
        @@users = {}
        @@next_id = 1
      end
    end

    # standard:disable Lint/ConstantDefinitionInBlock
    class UserRegistrationExample < Operations::V2::Task
      has_attribute :email, :string
      validates :email, presence: true
      has_attribute :name, :string
      has_model :user, "V2Examples::User"
      delay 3600  # 1 hour
      timeout 86400  # 24 hours
      starts_with :send_invitation

      action :send_invitation do
        # InvitationMailer.with(email: email).invitation.deliver_later
      end
      go_to :name_provided?

      wait_until :name_provided? do
        condition { name.present? }
        go_to :create_user
      end

      interaction :register! do |name|
        self.name = name
      end

      action :create_user do
        self.user = V2Examples::User.create! name: name
      end
      go_to :done

      result :done
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    before(:each) do
      User.reset!
    end

    it "starts and then waits for the user to interact" do
      registration = UserRegistrationExample.call email: "alice@example.com"

      expect(registration).to be_waiting
      expect(registration).to be_waiting_until "name_provided?"

      registration.register! "Bob Badger"

      expect(registration).to be_completed
      expect(registration.user).to_not be_nil
      expect(registration.user.name).to eq "Bob Badger"
      expect(registration).to be_in "done"
    end

    it "sets the wake up time and timeout" do
      registration = UserRegistrationExample.call email: "alice@example.com"

      expect(registration).to be_waiting
      # Initial wake time is 1 hour (3600 seconds) from now
      expect(registration.wake_at).to be > Time.now.utc + 3500
      expect(registration.timeout_at).to be > Time.now.utc + 86000
    end

    it "does not wake up if it has expired" do
      registration = UserRegistrationExample.call email: "alice@example.com"
      registration.timeout_at = Time.now.utc - 60
      Operations::V2.storage.save(registration)

      expect { registration.wake_up! }.to raise_error Operations::V2::Timeout
    end

    it "runs the task in the background" do
      registration = UserRegistrationExample.perform_later email: "alice@example.com"

      expect(registration).to be_waiting
      expect(registration).to be_in("send_invitation")
    end
  end
end
