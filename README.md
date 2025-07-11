# Operations
Build your business logic operations in an easy to understand format.  

Most times when I'm adding a feature to a complex application, I tend to end up drawing a flowchart.  

"We start here, then we check that option and if it's true then we do this, if it's false then we do that"

In effect, that flowchart is a state machine - with "decision states" and "action states".  And Operations is intended to be a way of designing your ruby class so that flowchart becomes easy to follow.  

## Breaking Change

Version 0.7.0 includes breaking changes.  When you run `bin/rails operations:migrations:install` one of the migrations will drop your existing `operations_tasks` and `operations_task_participants` tables.  If you need the historic data in those tables, then edit the migration to rename the tables instead.  Also you will need to update your tests to use the new `test` method. 

## Usage

### Drawing up a plan

Here's a simple example for planning a party.  

```ruby
class PlanAParty < Operations::Task
  has_attribute :date
  validates :date, presence: true 
  has_models :friends 
  has_model :food_shop 
  has_model :beer_shop
  has_models :available_friends
  starts_with :what_day_is_it?

  decision :what_day_is_it? do 
    condition { date.wday == 6 }
    go_to :buy_food
    condition { date.wday == 0 }
    go_to :relax
    condition { date.wday.in? [1, 2, 3, 4, 5]}
    go_to :go_to_work
  end 

  action :buy_food do 
    food_shop.order_party_food
  end
  go_to :buy_beer

  action :buy_beer do 
    beer_shop.order_drinks
  end
  go_to :invite_friends 

  action :invite_friends do 
    self.available_friends = friends.select { |friend| friend.available_on? date }
  end
  go_to :party!

  result :party!
  result :relax
  result :go_to_work
end
```

This task expects a date, a list of friends and a place to buy food and beer and consists of seven _states_ - `what_day_is_it?`, `buy_food`, `buy_beer`, `invite_fiends`, `party!`, `relax` and `go_to_work`.  

We would start the task as follows:

```ruby
task = PlanAParty.call date: Date.today, friends: @friends, food_shop: @food_shop, beer_shop: @beer_shop

expect(task).to be_completed
# If it's a weekday
expect(task).to be_in "go_to_work"
# If it's Sunday
expect(task).to be_in "relax"
# If it's Saturday
expect(task).to be_in "party!"
expect(task.available_friends).to_not be_empty
```
We define the `attributes` that the task contains and its starting `state`.  

The initial state is `what_day_is_it?` which is a _decision_ that checks the date supplied and moves to a different state based upon the conditions defined.  `buy_food`, `buy_drinks` and `invite_friends` are _actions_ which do things.  Whereas `party!`, `relax` and `go_to_work` are _results_ which end the task.  

When you `call` the task, it runs through the process immediately and either fails with an exception or completes immediately.  You can test `completed?` or `failed?` and check the `current_state`.  

If you prefer, `call` is alised as `perform_now`.  

### States

`States` are the heart of each task.  Each `state` defines a `handler` which does something, then moves to another `state`.  

You can test the current state of a task via its `current_state` attribute, or by the helper method `in? "some_state"`.  

### Action Handlers

An action handler does some work, and then transitions to another state. Once the action is completed, the task moves to the next state, which is specified using the `go_to` method or with a `then` declaration.  

```ruby 
action :have_a_party do
  self.food = task.buy_some_food_for(number_of_guests)
  self.beer = task.buy_some_beer_for(number_of_guests)
  self.music = task.plan_a_party_playlist
end
go_to :send_invitations
```
This is the same as: 
```ruby 
action :have_a_party do
  self.food = task.buy_some_food_for(number_of_guests)
  self.beer = task.buy_some_beer_for(number_of_guests)
  self.music = task.plan_a_party_playlist
end.then :send_invitations
```

[Example action handler](/spec/examples/single_action_spec.rb)

### Decision Handlers

A decision handler evaluates a condition, then changes state depending upon the result. 

The simplest tests a boolean condition. 

```ruby
decision :is_it_the_weekend? do 
  condition { Date.today.wday.in? [0, 6] }
  if_true :have_a_party 
  if_false :go_to_work
end
```

Alternatively, you can evaluate multiple conditions in your decision handler.  

```ruby 
decision :is_the_weather_good? do 
  condition { weather_forecast.sunny? }
  go_to :the_beach 
  condition { weather_forecast.rainy? }
  go_to :grab_an_umbrella 
  condition { weather_forecast.snowing? }
  go_to :build_a_snowman 
end
```

If no conditions are matched then the task fails with a `NoDecision` exception.

As a convention, use a question to name your decision handlers.  

[Example decision handler](/spec/examples/conditional_action_spec.rb)

### Result Handlers

A result handler marks the end of an operation.  It's pretty simple.  

```ruby
result :done
```

After this result handler has executed, the task will then be marked as `completed?` and the task's `current_state` will be "done".  

### Waiting and interactions

Many processes involve waiting for some external event to take place.  

A great example is user registration.  The administrator sends an invitation email, the recipient clicks the link, enters their details, and once completed, the user record is created.  This can be modelled as follows: 

```ruby
class UserRegistrationExample < Operations::Task
  has_attribute :email, :string
  validates :email, presence: true
  has_attribute :name, :string
  has_model :user, "User"
  delay 1.hour
  timeout 7.days
  starts_with :send_invitation

  action :send_invitation do
    UserMailer.with(email: email).invitation.deliver_later
  end
  go_to :name_provided?

  wait_until :name_provided? do
    condition { name.present? }
    go_to :create_user
  end

  interaction :register! do |name|
    self.name = name
  end.when :name_provided?

  action :create_user do
    self.user = User.create! name: name
  end
  go_to :done

  result :done
end
```
#### Wait handlers 

The registration process performs an action, `send_invitation` and then waits until a `name_provided?`.  A `wait handler` is similar to a `decision handler` but if the conditions are not met, instead of raising an error, the task goes to sleep.  A background process (see below) wakes the task periodically to reevaluate the condition.  Or, an `interaction` can be triggered; this is similar to an action because it does something, but it also immediately reevaluates the current wait handler.  So in this case, when the `register!` interaction completes, the `name_provided?` wait handler is reevaluated and, because the `name` has now been supplied, it can move on to the `create_user` state.  

When a task reaches a wait handler, it goes to sleep and expects to be woken up at some point in the future.  You can specify how often it is woken up by adding a `delay 10.minutes` declaration to your class.  The default is `1.minute`.  Likewise, if a task does not change state after a certain period it fails with an `Operations::Timeout` exception.  You can set this timeout by declaring `timeout 48.hours` (the default is `24.hours`).  

Like decisions, use a question as the name for your wait handlers.

#### Interactions 

Interactions are defined with the `interaction` declaration and they always wake the task.  The handler adds a new method to the task object - so in this case you would call `@user_registration.register! "Alice"` - this would wake the task, call the `register!` interaction handler, which in turn sets the name to `Alice`.  The wait handler would then be evaluated and the "create_user" and "done" states would be executed.  Also note that the `register!` interaction can only be called when the state is `name_provided?`.  This means that, if Alice registers, then someone hacks her email and uses the same invitation again, when the `register!` method is called, it will fail with an `Operations::InvalidState` exception - because Alice has already registered, the current state is "done" meaning this interaction cannot be called. 

As a convention, use an exclamation mark to name your interaction handlers.  

#### Background processor 

In order for `wait handlers` and `interactions` to work, you need to wake up the sleeping tasks by calling `Operations::Task.wake_sleeping`.  You can add this to a rake task that is triggered by a cron job, or if you use SolidQueue you can add it to your `recurring.yml`.  Alternatively, you can run `Operations::Task::Runner.start` - this is a long running process that wakes sleeping tasks every 30 seconds (and deletes old tasks).  

#### Starting tasks in the background

When a task is started, it runs in the current thread - so if you start the task within a controller, it will run in the context of your web request.  When it reaches a wait handler, the execution stops and control returns to the caller.  The background processor then uses ActiveJob to wake the task at regular intervals, evaluating the wait handler and either progressing if a condition is met or going back to sleep if the conditions are not met.  Because tasks go to sleep and the job that is processing it then ends, you should be able to create hundreds of tasks at any one time without starving your application of ActiveJob workers (although there may be delays when processing if your queues are full).

If you want the task to be run completely in the background (so it sleeps immediately and then starts when the background processor wakes it), you can call `MyTask.later(...)` (which is also aliased as `perform_later`).

[Example wait and interaction handlers](spec/examples/waiting_and_interactions_spec.rb)

### Sub tasks

If your task needs to start sub-tasks, it can use the `start` method, passing the sub-task class and arguments.  

```ruby 
action :start_sub_tasks do 
  3.times { |i| start OtherThingTask, number: i }
end
```
Sub-tasks are always started in the background so they do not block the progress of their parent task.  You can then track those sub-tasks using the `sub_tasks`, `active_sub_tasks`, `completed_sub_tasks` and `failed_sub_tasks` associations in a wait handler.  

```ruby
wait_until :sub_tasks_have_completed? do 
  condition { sub_tasks.all? { |st| st.completed? } }
  go_to :all_sub_tasks_completed 
  condition { sub_tasks.any? { |st| st.failed? } }
  go_to :some_sub_tasks_failed
end
```

#### Indexing data and results

If your task references other ActiveRecord models, you may need to find which tasks your models were involved in.  For example, if you want to see which tasks a particular user initiated.  You can declare an `index` on any `has_model` or `has_models` definitions and the task will automatically create a polymorphic join table that can be searched.  You can then `include Operations::Participant` into your model to find which tasks it was involved in (and which attribute it was stored under).  

For example: 

```ruby
class IndexesModelsTask < Operations::Task
  has_model :user, "User"
  validates :user, presence: true
  has_models :documents, "Document"
  has_attribute :count, :integer, default: 0
  index :user, :documents
  ... 
end

@task = IndexesModelsTask.call user: @user, documents: [@document1, @document2]

@user.operations.include?(@task) # => true 
@user.operations_as(:user).include?(@task) # => true 
@user.operations_as(:documents).include?(@task) # => false - the user is stored in the user attribute, not the documents attribute
```

### Failures and exceptions

If any handlers raise an exception, the task will be terminated. It will be marked as `failed?` and the details of the exception will be stored in `exception_class`, `exception_message` and `exception_backtrace`.  

### Task life-cycle and the database

There is an ActiveRecord migration that creates the `operations_tasks` table.  Use `bin/rails operations:install:migrations` to copy it to your application, then run `bin/rails db:migrate` to add the table to your application's database.  

When you `call` a task, it is written to the database.  Then whenever a state transition occurs, the task record is updated.  

This gives you a number of possibilities: 
- you can access the data (or error state) of a task after it has completed
- you can use [TurboStream broadcasts](https://turbo.hotwired.dev/handbook/streams) to update your user-interface as the state changes
- tasks can wait until an external event of some kind
- the tasks table acts as an audit trail or activity log for your application

However, it also means that your database table could fill up with junk that you're no longer interested in.  Therefore you can specify the maximum age of a task and, periodically, clean old tasks away.  Every task has a `delete_at` field that, by default, is set to `90.days.from_now`.  This can be changed by declaring `delete_after 7.days` - which will then mark the `delete_at` field for instances of that particular class to seven days.  To actually delete those records you should set a cron job or recurring task that calls `Operations::Task.delete_old`.  If you use the `Operations::Task::Runner`, it does this automatically.  

## Testing

Because the flow for a task may be complex, it's best to test each state in isolation.  To help with this, there is a `test` method on the `Operations::Task` class, which creates a task, in your desired state, then runs the appropriate handler.  Then you can check that it has done what you expect.  

```ruby 
class WeekendChecker < Operations::Task
  has_attribute :day_of_week, :string, default: "Monday"
  validates :day_of_week, presence: true
  starts_with :is_it_the_weekend?

  decision :is_it_the_weekend? do
    condition { %w[Saturday Sunday].include? day_of_week }
    if_true :weekend
    if_false :weekday
  end

  result :weekend
  result :weekday
end

task = WeekendChecker.test :is_it_the_weekend?, day_of_week: "Saturday"
expect(task).to be_in :weekend

task = WeekendChecker.test :is_it_the_weekend?, day_of_week: "Wednesday"
expect(task).to be_in :weekday
```

## Installation
Step 1: Add the gem to your Rails application's Gemfile:
```ruby
gem "standard_procedure_operations"
```
Step 2: Run `bundle install`, then copy and run the migrations to add the tasks table to your database:
```sh
bin/rails operations:install:migrations 
bin/rails db:migrate
```
Step 3: Create your own operations by inheriting from `Operations::Task` and revel in the stateful flowcharts!
```ruby
class DailyLife < Operations::Task
  starts_with :am_i_awake?

  decision :am_i_awake? do 
    condition { (7..23).include?(Time.now.hour) }

    if_true :live_like_theres_no_tomorrow 
    if_false :rest_and_recuperate
  end 

  result :live_like_theres_no_tomorrow 
  result :rest_and_recuperate
end
```
Step 4: If you're using RSpec for testing, add `require "operations/matchers" to your "spec/rails_helper.rb" file.

## License
The gem is available as open source under the terms of the [LGPL License](/LICENSE).  This may or may not make it suitable for your needs.

## Roadmap

- [x] Specify inputs (required and optional) per-state, not just at the start
- [x] Always raise errors instead of just recording a failure (will be useful when dealing with sub-tasks)
- [x] Deal with actions that have forgotten to call `go_to` by enforcing static state transitions with `go_to`
- [x] Simplify calling sub-tasks (and testing them)
- [ ] Figure out how to stub calling sub-tasks with known results data 
- [ ] Figure out how to test the parameters passed to sub-tasks when they are called
- [x] Make Operations::Task work in the background using ActiveJob
- [x] Add pause/resume capabilities (for example, when a task needs to wait for user input)
- [x] Add wait for sub-tasks capabilities
- [x] Add visualization export for task flows
- [ ] Replace ActiveJob with a background process
- [ ] Rename StateManagent with Plan
- [ ] Add interactions
