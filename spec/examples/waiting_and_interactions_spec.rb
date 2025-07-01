require "rails_helper"

module Examples
  RSpec.describe "Waiting and Interactions", type: :model do
    # standard:disable Lint/ConstantDefinitionInBlock
    class UserRegistrationExample < Operations::Task
      has_attribute :email, :string
      validates :email, presence: true
      has_attribute :name, :string
      has_model :user, "User"
      delay 1.hour
      timeout 24.hours
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
      go_to :name_provided?

      action :create_user do
        self.user = User.create! name: name
      end
      go_to :done

      result :done
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    it "starts and then waits for the user to interact" do
      registration = UserRegistrationExample.call email: "alice@example.com"

      expect(registration).to be_waiting
      expect(registration).to be_waiting_until "name_provided?"

      registration.register! "Bob Badger"

      expect(registration).to be_completed
      expect(registration.user).to_not be_nil
      expect(registration.user.name).to eq "Bob Badger"
    end

    it "sets the wake up time and timeout" do
      registration = UserRegistrationExample.call email: "alice@example.com"

      expect(registration).to be_waiting
      expect(registration.wakes_at).to be > 59.minutes.from_now
      expect(registration.expires_at).to be > 23.hours.from_now
    end

    it "does not wake up if it has expired" do
      registration = UserRegistrationExample.call email: "alice@example.com"

      registration.update! wakes_at: 1.minute.ago, expires_at: 1.minute.ago

      expect { registration.wake_up! }.to raise_error Operations::Timeout
    end
  end
end
