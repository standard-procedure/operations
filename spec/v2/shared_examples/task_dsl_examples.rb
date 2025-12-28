# Shared examples for testing V2 Task DSL compatibility
# Any storage/executor adapter combination should pass these tests
RSpec.shared_examples "Operations V2 Task DSL" do
  describe "Actions" do
    # standard:disable Lint/ConstantDefinitionInBlock
    class SaysHelloExample < Operations::V2::Task
      has_attribute :name, :string
      validates :name, presence: true
      has_attribute :salutation, :string, default: "Hello"

      starts_with :generate_greeting

      action :generate_greeting do
        self.message = "#{salutation} #{name}"
      end
      go_to :done

      result :done
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    it "generates greeting" do
      task = SaysHelloExample.call name: "World"
      expect(task).to be_completed
      expect(task.message).to eq "Hello World"
    end

    it "allows salutation override" do
      task = SaysHelloExample.call name: "World", salutation: "Goodbye"
      expect(task).to be_completed
      expect(task.message).to eq "Goodbye World"
    end

    it "validates required fields" do
      expect {
        SaysHelloExample.call salutation: "Hello"
      }.to raise_error Operations::V2::ValidationError
    end
  end

  describe "Decisions" do
    # standard:disable Lint/ConstantDefinitionInBlock
    class SaysHelloOrGoodbyeExample < Operations::V2::Task
      has_attribute :name, :string
      has_attribute :arriving, :boolean, default: true

      starts_with :greeting

      decision :greeting do
        condition { arriving? }
        if_true :say_hello
        if_false :say_goodbye
      end

      action :say_hello do
        self.message = "Hello #{name}"
      end
      go_to :done

      action :say_goodbye do
        self.message = "Goodbye #{name}"
      end
      go_to :done

      result :done
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    it "says hello when arriving" do
      task = SaysHelloOrGoodbyeExample.call(name: "Alice", arriving: true)
      expect(task).to be_completed
      expect(task.message).to eq "Hello Alice"
    end

    it "says goodbye when leaving" do
      task = SaysHelloOrGoodbyeExample.call(name: "Alice", arriving: false)
      expect(task).to be_completed
      expect(task.message).to eq "Goodbye Alice"
    end
  end

  describe "Testing individual states" do
    # standard:disable Lint/ConstantDefinitionInBlock
    class ReportGeneratorExample < Operations::V2::Task
      has_attribute :day, :string

      starts_with :check_day

      decision :check_day do
        condition { day == "Saturday" || day == "Sunday" }
        go_to :weekend_report

        condition { true }
        go_to :weekday_report
      end

      action :weekend_report do
        self.report_type = "weekend"
      end
      go_to :done

      action :weekday_report do
        self.report_type = "weekday"
      end
      go_to :done

      result :done
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    it ".test method works for Saturday" do
      task = ReportGeneratorExample.test :check_day, day: "Saturday"
      expect(task).to be_in("weekend_report")
    end

    it ".test method works for Wednesday" do
      task = ReportGeneratorExample.test :check_day, day: "Wednesday"
      expect(task).to be_in("weekday_report")
    end
  end

  describe "Sub-tasks" do
    # Mock Article model
    before(:all) do
      unless defined?(MockArticle)
        class MockArticle
          attr_accessor :id, :title, :published

          @@articles = {}
          @@next_id = 1

          def self.create!(attributes)
            article = new
            article.id = @@next_id
            @@next_id += 1
            article.title = attributes[:title]
            article.published = false
            @@articles[article.id] = article
            article
          end

          def self.find(id)
            @@articles[id]
          end

          def self.reset!
            @@articles = {}
            @@next_id = 1
          end

          def publish!
            self.published = true
          end

          def published?
            published
          end
        end
      end
    end

    # standard:disable Lint/ConstantDefinitionInBlock
    class PublishArticleExample < Operations::V2::Task
      has_model :article, "MockArticle"

      starts_with :publish

      action :publish do
        article.publish!
      end
      go_to :done

      result :done
    end

    class PublishMultipleArticlesExample < Operations::V2::Task
      has_models :articles, "MockArticle"

      starts_with :publish_all

      action :publish_all do
        articles.each do |article|
          start PublishArticleExample, article: article
        end
      end
      go_to :done

      result :done
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    before(:each) do
      MockArticle.reset!
    end

    it "starts sub-tasks" do
      articles = 3.times.map { |i| MockArticle.create! title: "Article #{i}" }
      parent = PublishMultipleArticlesExample.call articles: articles

      expect(parent).to be_completed
      expect(parent.sub_tasks.size).to eq 3
      expect(parent.sub_tasks).to all(be_completed)
      expect(articles).to all(be_published)
    end
  end

  describe "Waiting and Interactions" do
    # Mock User model
    before(:all) do
      unless defined?(MockUser)
        class MockUser
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
      end
    end

    # standard:disable Lint/ConstantDefinitionInBlock
    class UserRegistrationExample < Operations::V2::Task
      has_attribute :email, :string
      validates :email, presence: true
      has_attribute :name, :string
      has_model :user, "MockUser"
      delay 3600 # 1 hour
      timeout 86400 # 24 hours
      starts_with :send_invitation

      action :send_invitation do
        # InvitationMailer.with(email: email).invitation.deliver_later
      end
      go_to :name_provided?

      wait_until :name_provided? do
        condition { !name.nil? && !name.empty? }
        go_to :create_user
      end

      interaction :register! do |name|
        self.name = name
      end

      action :create_user do
        self.user = MockUser.create! name: name
      end
      go_to :done

      result :done
    end
    # standard:enable Lint/ConstantDefinitionInBlock

    before(:each) do
      MockUser.reset!
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
