# Operations
Build your business logic operations in an easy to understand format.  

Most times when I'm adding a feature to a complex application, I tend to end up drawing a flowchart.  

"We start here, then we check that option and if it's true then we do this, if it's false then we do that"

In effect, that flowchart is a state machine - with "decision states" and "action states".  And Operations is intended to be a way of designing your ruby class so that flowchart becomes easy to follow.  

## Usage

### Drawing up a plan

Here's a simple example for planning a party.  

```ruby
class PlanAParty < Operations::Task
  input :date, :friends, :food_shop, :beer_shop
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

  result :party! do |results|
    results.available_friends = available_friends
  end
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
expect(task.state).to eq "go_to_work"
# If it's Sunday
expect(task.state).to eq "relax"
# If it's Saturday
expect(task.state).to eq "party!"
expect(task.results[:available_friends]).to_not be_empty
```
We define the `inputs` that the task expects and its starting `state`.  

The initial state is `what_day_is_it?` which is a _decision_ that checks the date supplied and moves to a different state based upon the conditions defined.  `relax` and `go_to_works` are _results_ which end the task.  Whereas `buy_food`, `buy_drinks` and `invite_friends` are _actions_ which do things.  And the `party!` _result_ also returns some data - a list of `available_friends`.  

When you `call` the task, it runs through the process immediately and either fails with an exception or completes immediately.  

You can also plan tasks that continue working over a period of time.  These [Agents](/docs/agents.md) have extra capabilities - `wait_until` and `interaction`s - but require a bit of setup, so we'll come back to them later.  

### States

`States` are the heart of each task.  Each `state` defines a `handler` which does something, then moves to another `state`.  

Any state can also declare which data it expects - both required `inputs`, as well as `optional` inputs.  If the task enters a `state` and the required data is not present then it fails with an `ArgumentError`.  Optional input declarations do not actually do anything but are useful for documenting your task.  

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

A decision can also mark a failure, which will terminate the task and raise an `Operations::Failure`.  
```ruby
decision :authorised? do 
  condition { user.administrator? }

  if_true :do_some_work 
  if_false { fail_with "Unauthorised" }
end
```
(In theory the block used in the `fail_with` case can do anything within the [DataCarrier context](#data-and-results) - so you could set internal state or call methods on the containing task - but I've not tried this yet).

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

You can specify the data that is required for a decision handler to run by specifying `inputs` and `optionals`:
```ruby
decision :authorised? do 
  inputs :user 
  optional :override
  condition { override || user.administrator? }

  if_true :do_some_work 
  if_false { fail_with "Unauthorised" }
end
```

### Action Handlers

An action handler does some work, and then transitions to another state. The state transition is defined statically after the action, using the `go_to` method.

```ruby 
action :have_a_party do
  self.food = task.buy_some_food_for(number_of_guests)
  self.beer = task.buy_some_beer_for(number_of_guests)
  self.music = task.plan_a_party_playlist
end
go_to :send_invitations
```

You can also specify the required and optional data for your action handler using parameters or within the block. 

```ruby 
action :have_a_party do 
  inputs :number_of_guests 
  optional :music
  self.food = task.buy_some_food_for(number_of_guests)
  self.beer = task.buy_some_beer_for(number_of_guests)
  self.music ||= task.plan_a_party_playlist
end
go_to :send_invitations
```

### Result Handlers

A result handler marks the end of an operation, optionally returning some results.  You need to copy your desired results from your [data](#data-and-results) to your results object.  This is so only the information that matters to you is stored as the results.  

```ruby
action :send_invitations do 
  self.invited_friends = (0..number_of_guests).collect do |i|
    friend = friends.pop
    FriendsMailer.with(recipient: friend).party_invitation.deliver_later unless friend.nil?
    friend 
  end.compact
end
go_to :ready_to_party

result :ready_to_party do |results|
  results.invited_friends = invited_friends
end
```
After this result handler has executed, the task will then be marked as `completed?`, the task's state will be `ready_to_party` and `results[:invited_friends]` will contain an array of the people you sent invitations to.  

If you don't have any meaningful results, you can omit the block on your result handler.  
```ruby
result :go_to_work
```
In this case, the task will be marked as `completed?`, the task's state will be `go_to_work` and `results` will be empty.  

You can also specify the required and optional data for your result handler within the block.  

```ruby
result :ready_to_party do |results|
  inputs :invited_friends 

  results.invited_friends = invited_friends
end
```

### Calling an operation

Each task has a `call` method that takes your inputs and runs the task immediately.  You can then test to see if it has `completed?` or `failed?` and check the final `state` and `results`

```ruby
begin 
  task = PlanAParty.call date: Date.today, friends: @friends, food_shop: @food_shop, beer_shop: @beer_shop

  expect(task).to be_completed
  # If it's a weekday
  expect(task.state).to eq "go_to_work"
  # If it's Sunday
  expect(task.state).to eq "relax"
  # If it's Saturday
  expect(task.state).to eq "party!"
  expect(task.results[:available_friends]).to_not be_empty
rescue => ex 
  expect(task).to be_failed
  expect(task.results[:exception_message]).to eq ex.message
  expect(task.results[:exception_class]).to eq ex.class
end
```

OK - so that's a pretty longwinded way of performing a simple task.  

But many operations end up as complex flows of conditionals and actions, often spread across multiple classes and objects.  This means that someone trying to understand the rules for an operation can spend a lot of time tracing through code, understanding that flow.  

In [Collabor8Online](https://www.collabor8online.co.uk/), when a user wants to download a file, the task is complicated, based upon feature flags, configuration options and permissions.  This involves over fifteen decisions, fifteen actions and, previously, the logic for this was scattered across a number of models and controllers, making it extremely difficult to see what was happening.  Whereas now, all the logic for downloads is captured within one overall plan that calls out to three other sub-tasks and the logic is easy to follow.  

### Data and results

Each operation carries its own, mutable, [data](/app/models/operations/task/data_carrier.rb) for the duration of the operation.  

This is provided when you `call` the operation to start it and is passed through to each decision, action and result.  If you modify the data then that modification is passed on to the next handler.  

Within handlers you can read the data directly (the implementation uses `instance_eval`/`instance_exec`).  Here the `build_name` action knows the `first_name` and `last_name` provided and adds in a new property of `name`.  

```ruby 
class CombineNames < Operations::Task 
  inputs :first_name, :last_name 
  starts_with :build_name 

  action :build_name do 
    self.name = "#{first_name} #{last_name}"
    go_to :done 
  end

  result :done do |results|
    results.name = name 
  end
end

task = CombineNames.call first_name: "Alice", last_name: "Aardvark"
task.results[:name] # => Alice Aardvark
```

Because handlers are run in the context of the data carrier, you do not have direct access to methods or properties on your task object.  However, the data carrier holds a reference to your task; use `task.do_something` or `task.some_attribute` to access it.  The exception is the `fail_with`, `call` and `start` methods which the data carrier understands (and are intercepted when you are [testing](#testing)). 

Both your task's `data` and its final `results` are stored in the database, so they can be examined later.  The `results` because that's what you're interested in, the `data` as it can be useful for debugging or auditing purposes.  

They are both stored as hashes that are encoded into JSON.  

Instead of using the standard [JSON coder](https://api.rubyonrails.org/v4.2/classes/ActiveModel/Serializers/JSON.html), we use a [GlobalIdSerialiser](https://github.com/standard-procedure/global_id_serialiser).  This serialises most data into standard JSON types, as you would expect, but it also takes any [GlobalID::Identification](https://github.com/rails/globalid) objects (which includes all ActiveRecord models) and converts them to a GlobalID string.  Then when the data is deserialised from the database, the GlobalID is converted back into the appropriate model.  

If the original database record was deleted between the time the hash was serialised and when it was retrieved, the `GlobalID::Locator` will fail.  In this case, the deserialised data will contain a `nil` for the value in question.  

Also note that the GlobalIdSerialiser automatically converts all hash keys into symbols (unlike the standard JSON coder which uses strings).  

#### Indexing data and results

If you need to search through existing tasks by a model that is stored in the `data` or `results` fields - for example, you might want to list all operations that were started by a particular `User` - the models can be indexed alongside the task.  

If your ActiveRecord model (in this example, `User`) includes the `Operations::Participant` module, it will be linked with any task that references that model.  A polymorphic join table, `operations_task_participants` is used for this.  Whenever a task is saved, any `Operations::Participant` records are located in the `data` and `results` collections and a `Operations::TaskParticipant` record created to join the model to the task.  The `context` attribute records whether the association is in the `data` or `results` collection and the `role` attribute is the name of the hash key.  

For example, you create your task as:
```ruby
@alice = User.find 123
@task = DoSomethingImportant.call user: @alice 
```
There will be a `TaskParticipant` record with a `context` of "data", `role` of "user" and `participant` of `@alice`.  

Likewise, you can see all the tasks that Alice was involved with using: 
```ruby
@alice.involved_in_operations_as("user") # => collection of tasks where Alice was a "user" in the "data" collection
@alice.involved_in_operations_as("user", context: "results") # => collection of tasks where Alice was a "user" in the "results" collection
```

### Failures and exceptions

If any handlers raise an exception, the task will be terminated. It will be marked as `failed?` and the `results` hash will contain `results[:failure_message]`, `results[:exception_class]` and `results[:exception_backtrace]` for the exception's message, class name and backtrace respectively.  

You can also stop a task at any point by calling `fail_with message`.  This will raise an `Operations::Failure` exception, marking the task as `failed?` and the `results` has will contain `results[:failure_message]`.

### Task life-cycle and the database

There is an ActiveRecord migration that creates the `operations_tasks` table.  Use `bin/rails operations:install:migrations` to copy it to your application, then run `bin/rails db:migrate` to add the table to your application's database.  

When you `call` a task, it is written to the database.  Then whenever a state transition occurs, the task record is updated.  

This gives you a number of possibilities: 
- you can access the results (or error state) of a task after it has completed
- you can use [TurboStream broadcasts](https://turbo.hotwired.dev/handbook/streams) to update your user-interface as the state changes - see "[status messages](#status-messages)" below
- tasks can run in the background (using ActiveJob) and other parts of your code can interact with them whilst they are in progress - see "[background operations](#background-operations-and-pauses)" below
- the tasks table acts as an audit trail or activity log for your application

However, it also means that your database table could fill up with junk that you're no longer interested in.  Therefore you can specify the maximum age of a task and, periodically, clean old tasks away.  Every task has a `delete_at` field that, by default, is set to `90.days.from_now`.  This can be changed by calling `Operations::Task.delete_after 7.days` (or whatever value you prefer) in an initializer.  Then, run a cron job, or other scheduled task, once per day that calls `Operations::Task.delete_expired`.  This will delete any tasks whose `delete_at` time has passed.  

### Status messages

Documentation coming soon.  

### Sub tasks

Any operation can be composed out of other operations and can therefore call other subtasks.  

```ruby
class PrepareDownload < Operations::Task 
  inputs :user, :document 
  starts_with :get_authorisation
  
  action :get_authorisation do 
    inputs :user, :document 

    result = call GetAuthorisation, user: user, document: document 
    self.authorised = result[:authorised]
  end
  go_to :whatever_happens_next
end
```
If the sub-task succeeds, `call` returns the results from the sub-task.  If it fails, then any exceptions are re-raised.  

You can also access the results in a block: 
```ruby
class PrepareDownload < Operations::Task 
  inputs :user, :document 
  starts_with :get_authorisation
  
  action :get_authorisation do 
    inputs :user, :document 

    call GetAuthorisation, user: user, document: document do |results|
      self.authorised = results[:authorised]
    end
  end
  go_to :whatever_happens_next
end
```

### Agents

So far, we've only defined tasks that run and complete immediately.  However, [agents](/docs/agents.md) run over a long period of time and can respond to external interactions.  

## Testing

Tasks represent complex flows of logic, so each state can be [tested in isolation](/docs/testing.md).

## Visualisation

There is a very simple [visualisation tool](/docs/visualisation.md) built into the gem. 

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