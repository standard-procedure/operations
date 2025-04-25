require "rails_helper"

module Examples
  RSpec.describe "User Registration Examples", type: :model do
    # standard:disable Lint/ConstantDefinitionInBlock
    class UserRegistrationSpec < Operations::Agent
      starts_with :start

      action :start do
        self.pin = rand(100000..899999)
        self.pin_value = 0
        self.first_name = ""
        self.last_name = ""
        self.email = ""
      end
      go_to :pin_correct?

      wait_until :pin_correct? do
        condition { pin == pin_value }
        go_to :registration_completed?
      end

      wait_until :registration_completed? do
        condition { first_name.present? && last_name.present? && email.present? }
        go_to :done
      end

      result :done

      interaction :enter_pin do |value|
        self.pin_value = value.to_i
      end.when :pin_correct?

      interaction :complete_registration do |first_name, last_name, email|
        self.first_name = first_name
        self.last_name = last_name
        self.email = email
      end.when :registration_completed?
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    it "waits for the PIN to be entered" do
      registration = UserRegistrationSpec.start
      expect(registration.state).to eq "pin_correct?"
    end

    it "carries on waiting if the wrong PIN is entered" do
      registration = UserRegistrationSpec.start

      registration.enter_pin "999"

      expect(registration.state).to eq "pin_correct?"
    end

    it "does not allow registration details to be entered if it is waiting for a PIN" do
      registration = UserRegistrationSpec.start

      expect { registration.complete_registration "Alice", "Aardvark", "alice@example.com" }.to raise_error(Operations::InvalidState)
    end

    it "waits for the registration to complete if the correct PIN is entered" do
      registration = UserRegistrationSpec.start
      correct_pin = registration.data[:pin]

      registration.enter_pin correct_pin.to_s

      expect(registration.state).to eq "registration_completed?"
    end

    it "registers the user details" do
      registration = UserRegistrationSpec.start
      correct_pin = registration.data[:pin]
      registration.enter_pin correct_pin.to_s

      registration.complete_registration "Alice", "Aardvark", "alice@example.com"

      expect(registration).to be_completed
      expect(registration.data[:first_name]).to eq "Alice"
      expect(registration.data[:last_name]).to eq "Aardvark"
      expect(registration.data[:email]).to eq "alice@example.com"
    end
  end
end
