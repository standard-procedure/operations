# Operations
Build your business logic operations in an easy to understand format.  

Most times when I'm adding a feature to a complex application, I tend to end up drawing a flowchart.  

"We start here, then we check that option and if it's true then we do this, if it's false then we do that"

In effect, that flowchart is a state machine - with "decision states" and "action states".  And Operations is intended to be a way of designing your ruby class so that flowchart becomes easy to follow.  

## Usage
Here's a simplified example from [Collabor8Online](https://www.collabor8online.co.uk) - in C8O when you download a document, we need to check your access rights, as well as ensuring that the current user has not breached their monthly download limit.  In addition, some accounts have a "filename scrambler" switched on - where the original filename is replaced (which is a feature used by some of our clients on their customers' trial accounts).  

### Defining an operation
The flowchart, for this simplified example, is something like this: 

```
START -> CHECK AUTHORISATION
         Is this user authorised?
         NO -> FAIL
         YES -> CHECK DOWNLOAD LIMITS

         CHECK DOWNLOAD LIMITS
         Is this user within their monthly download limit?
         NO -> FAIL
         YES -> CHECK FILENAME SCRAMBLER

         CHECK FILENAME SCRAMBLER
         Is the filename scrambler switched on for this account?
         NO -> PREPARE DOWNLOAD
         YES -> SCRAMBLE FILENAME

         SCRAMBLE FILENAME
         Replace the filename with a scrambled one
         THEN -> PREPARE DOWNLOAD

         PREPARE DOWNLOAD
         Return the document's filename so it can be used when sending the document to the end user
         DONE
```

We have five states - three of which are decisions, one is an action and one is a result.  

Here's how this would be represented using Operations.  

```ruby
class PrepareDocumentForDownload < Operations::Task
  inputs :user, :document, :use_filename_scrambler
  starts_with :authorised?

  decision :authorised? do
    inputs :user
    condition { user.can?(:read, data.document) }

    if_true :within_download_limits?
    if_false { fail_with "unauthorised" }
  end

  decision :within_download_limits? do
    inputs :user
    condition { user.within_download_limits? }

    if_true :use_filename_scrambler?
    if_false { fail_with "download_limit_reached" }
  end

  decision :use_filename_scrambler? do
    inputs :use_filename_scrambler
    condition { use_filename_scrambler }

    if_true :scramble_filename
    if_false :return_filename
  end

  action :scramble_filename do
    inputs :document

    self.filename = "#{Faker::Lorem.word}#{File.extname(document.filename.to_s)}"
    go_to :return_filename
  end

  result :return_filename do |results|
    inputs :document
    optional :filename

    results.filename = filename || document.filename.to_s
  end
end

task = PrepareDocumentForDownload.call user: @user, document: @document, use_filename_scrambler: @account.feature_flags[:use_filename_scramber]
puts task.results[:filename]
```

The task declares that it requires `user`, `document` and `use_filename_scrambler` parameters and that it starts in the `authorised?` state.  

The five states are represented as three [decision](#decisions) handlers, one [action](#actions) handler and a [result](#results) handler.  

### Decisions
A decision handler evaluates a condition, then changes state depending upon if the result is true or false. 

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
In this case, the task will fail (with an `ArgumentError`) if there is no `user` specified.  However, `override` is optional (in fact the `optional` method does nothing and is just there for documentation purposes).

### Actions
An action handler does some work, then moves to another state.  

```ruby 
action :have_a_party do
  self.food = task.buy_some_food_for(number_of_guests)
  self.beer = task.buy_some_beer_for(number_of_guests)
  self.music = task.plan_a_party_playlist

  go_to :send_invitations
end
```
You can specify the required and optional data for your action handler within the block.  `optional` is decorative and to help with your documentation.  Ensure you call `inputs` at the start of the block so that the task fails before you do any meaningful work.  

```ruby 
action :have_a_party do
  inputs :number_of_guests 
  optional :music 

  self.food = task.buy_some_food_for(number_of_guests)
  self.beer = task.buy_some_beer_for(number_of_guests)
  self.music ||= task.plan_a_party_playlist

  go_to :send_invitations
end
```
Do not forget to call `go_to` from your action handler, otherwise the operation will just stop whilst still being marked as in progress.  (TODO: don't let this happen).

### Waiting
Wait handlers are very similar to decision handlers but only work within [background tasks](#background-operations-and-pauses).  

```ruby 
wait_until :weather_forecast_available? do 
  condition { weather_forecast.sunny? }
  go_to :the_beach 
  condition { weather_forecast.rainy? }
  go_to :grab_an_umbrella 
  condition { weather_forecast.snowing? }
  go_to :build_a_snowman 
end
```

If no conditions are met, then, unlike a decision handler, the task continues waiting in the same state.  

### Results
A result handler marks the end of an operation, optionally returning some results.  You need to copy your desired results from your [data](#data-and-results) to your results object.  This is so only the information that matters to you is stored as the results.  

```ruby
action :send_invitations do 
  self.invited_friends = (0..number_of_guests).collect do |i|
    friend = friends.pop
    FriendsMailer.with(recipient: friend).party_invitation.deliver_later unless friend.nil?
    friend 
  end.compact

  go_to :ready_to_party
end

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

You can also specify the required and optional data for your result handler within the block.  `optional` is decorative and to help with your documentation.  Ensure you call `inputs` at the start of the block.  
```ruby
action :send_invitations do 
  inputs :number_of_guests, :friends

  self.invited_friends = (0..number_of_guests).collect do |i|
    friend = friends.pop
    FriendsMailer.with(recipient: friend).party_invitation.deliver_later unless friend.nil?
    friend 
  end.compact

  go_to :ready_to_party
end

result :ready_to_party do |results|
  inputs :invited_friends 

  results.invited_friends = invited_friends
end
```

### Calling an operation
You would use the earlier [PrepareDocumentForDownload](spec/examples/prepare_document_for_download_spec.rb) operation in a controller like this:

```ruby
class DownloadsController < ApplicationController 
  def show 
    @document = Document.find(params[:id])
    @task = PrepareDocumentForDownload.call(user: Current.user, document: @document, use_filename_scrambler: Current.account.use_filename_scrambler?)

    send_data @document.contents, filename: @task.results[:filename], disposition: "attachment"

  rescue => failure
    render action: "error", locals: {error: failure.message}, status: 422
  end
end
```

OK - so that's a pretty longwinded way of performing a simple task.  

But many operations end up as complex flows of conditionals and actions, often spread across multiple classes and objects.  This means that someone trying to understand the rules for an operation can spend a lot of time tracing through code, understanding that flow.  

In Collabor8Online, the actual operation for handling downloads has over twenty states, with half of them being decisions (there are a number of feature flags and per-account configuration options which need to be considered).  Now they are defined as four ruby classes (using [composition](#sub-tasks) to split the workload) and the logic is extremely easy to follow.  

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

Because handlers are run in the context of the data carrier, you do not have direct access to methods or properties on your task object.  However, the data carrier holds a reference to your task; use `task.do_something` or `task.some_attribute` to access it.  The exceptions are the `go_to`, `fail_with`, `call` and `start` methods which the data carrier understands (and are intercepted when you are [testing](#testing)).  

Both your task's `data` and its final `results` are stored in the database, so they can be examined later.  The `results` because that's what you're interested in, the `data` as it can be useful for debugging or auditing purposes.  

They are both stored as hashes that are encoded into JSON.  

Instead of using the standard [JSON coder](https://api.rubyonrails.org/v4.2/classes/ActiveModel/Serializers/JSON.html), we use a [GlobalIDSerialiser](/lib/operations/global_id_serialiser.rb).  This uses [ActiveJob::Arguments](https://guides.rubyonrails.org/active_job_basics.html#supported-types-for-arguments) to transform any models into [GlobalIDs](https://github.com/rails/globalid) before storage and convert them back to models upon retrieval.  

If the original database record was deleted between the time the hash was serialised and when it was retrieved, the `GlobalID::Locator` will fail.  With ActiveJob, this means that the job cannot run and is discarded.  For Operations, we attempt to deserialise a second time, returning the GlobalID string instead of the model.  So be aware that when you access `data` or `results` you may receive a string (similar to `"gid://test-app/User/1"`) instead of the models you were expecting.  And the error handling deserialiser is very simple so you may get format changes in some of the data as well.  If serialisation fails you can access the original JSON string as `data.raw_data` or `results[:raw_data]`.  

TODO: Replace the ActiveJob::Arguments deserialiser with the [transporter](https://github.com/standard-procedure/plumbing/blob/main/lib/plumbing/actor/transporter.rb) from [plumbing](https://github.com/standard-procedure/plumbing)

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

    results = call GetAuthorisation, user: user, document: document 
    self.authorised = results[:authorised]

    go_to :whatever_happens_next
  end
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

    go_to :whatever_happens_next
  end
end
```

If you want the sub-task to be a [background task](#background-operations-and-pauses), use `start` instead of `call`.  This will return the newly created sub-task immediately.  As the sub-task will not have completed, you cannot access its results unless you [wait](#waiting-for-sub-tasks-to-complete) (which is only possible if the parent task is a background task as well).  

### Background operations and pauses
If you have ActiveJob configured, you can run your operations in the background.  

Instead of using `call`, use `start` to initiate the operation.  This takes the same data parameters and returns a task object that you can refer back to.  But it will be `waiting?` instead of `in_progress?` or `completed?`.  An `Operations::TaskRunnerJob` will be queued and it will mark the task as `in_progress?`, then call a _single_ state handler.  Instead of handling the next state immediately another `Operations::TaskRunnerJob` is queued.  And so on, until the task either fails or is completed.  

By itself, this is not particularly useful - it just makes your operation take even longer to complete.  

But if your operation may need to wait for something else to happen, background tasks are perfect.  

#### Waiting for user input
For example, maybe you're handling a user registration process and you need to wait until the verification link has been clicked.  The verification link goes to another controller and updates the user record in question.  Once clicked, you can then notify the administrator.  

```ruby
class UserRegistration < Operations::Task 
  inputs :email
  starts_with :create_user 
  
  action :create_user do 
    inputs :email 

    self.user = User.create! email: email
    go_to :send_verification_email 
  end 

  action :send_verification_email do 
    inputs :user 

    UserMailer.with(user: user).verification_email.deliver_later 
    go_to :verified? 
  end 

  wait_until :verified? do 
    condition { user.verified? }
    go_to :notify_administrator 
  end 

  action :notify_administrator do 
    inputs :user 

    AdminMailer.with(user: user).verification_completed.deliver_later
  end
end

@task = UserRegistration.start email: "someone@example.com"
```
Because background tasks use ActiveJobs, every time the `verified?` condition is evaluated, the task object (and hence its data) will be reloaded from the database.  So the `user.verified?` property will be refreshed on each evaluation.  

#### Waiting for sub-tasks to complete
Alternatively, you may have a number of sub-tasks that you want to run in parallel then continue once they have all completed.  This allows you to spread their execution across multiple processes or even servers (depending upon how your job queue processes are configured).

```ruby
class ParallelTasks < Operations::Task 
  inputs :number_of_sub_tasks
  starts_with :start_sub_tasks 
  
  action :start_sub_tasks do 
    inputs :number_of_sub_tasks
    self.sub_tasks = (1..number_of_sub_tasks).collect { |i| start LongRunningTask, number: i }
    go_to :do_something_else 
  end 

  action :do_something_else do 
    # do something else while the sub-tasks do their thing
    go_to :sub_tasks_completed? 
  end 

  wait_until :sub_tasks_completed? do 
    condition { sub_tasks.all? { |t| t.completed? } }
    go_to :done
  end 

  result :done 
end

@task = ParallelTasks.start number_of_sub_tasks: 5
```
The principle is the same as above; we store the newly created sub-tasks in our own `data` property.  As they are ActiveRecord models, they get reloaded each time `sub_tasks_completed?` is evaluated - and we check to see that they have all completed before moving on.  

#### Delays and Timeouts
When you run an operation in the background, it schedules an [ActiveJob](app/jobs/operations/task_runner_job.rb) which performs the individual state handler, scheduling a follow-up job for subsequent states.  By default, these jobs are scheduled to run after 1 second - so a five state operation will take a minimum of five seconds to complete (depending upon the backlog in your job queues).  This is to prevent a single operation from starving the job process of resources and allow other ActiveJobs the time to execute.  

However, if you know that your `wait_until` condition may take a while you can change the default delay to something longer.  In your operations definition, declare the required delay: 

```ruby
class ParallelTasks < Operations::Tasks 
  delay 1.minute
  ...
end
```

Likewise, it's possible for a background task to get stuck.  In the sub-tasks example above, if one of the sub-tasks fails, waiting for them _all_ to complete will never happen.  Every operation has a default timeout of 5 minutes - if the operation has not completed or failed 5 minutes after it was initially started, it will fail with an `Operations::Timeout` exception.  

If you need to change this (such as the user verification example above), you can declare the timeout when defining the operation.  Long timeouts fit well with longer delays, so you're not filling the job queues with jobs that are meaninglessly evaluating your conditions.

```ruby
class UserRegistration < Operations::Task 
  timeout 24.hours 
  delay 15.minutes
  ...
end
```

Instead of failing with an `Operations::Timeout` exception, you define an `on_timeout` handler for any special processing should the time-out occur.  

```ruby 
class WaitForSomething < Operations::Task 
  timeout 10.minutes 
  delay 1.minute 

  on_timeout do 
    Notifier.send_timeout_notification
  end
end
```

## Testing
Because operations are intended to model long, complex, flowcharts of decisions and actions, it can be a pain coming up with the combinations of inputs to test every path through the sequence.  

Instead, you can test each state handler _in isolation_.  

As the handlers are stateless, we can call one without hitting the database; instead creating a dummy task object and then triggering the handler with the correct parameters.  

This is done by calling `handling`, which yields a `test` object that we can inspect.

### Testing state transitions
To test if we have moved on to another state (for actions or decisions):
```ruby
MyOperation.handling(:an_action_or_decision, some: "data") do |test|
  assert_equal test.next_state, "new_state"
  # or
  expect(test).to have_moved_to "new_state"
end
```

### Testing data modifications
To test if some data has been set or modified (for actions):
```ruby
MyOperation.handling(:an_action, existing_data: "some_value") do |test|
  # has an existing data value been modified?
  assert_equal test.existing_data, "some_other_value"
  # or
  expect(test.existing_data).to eq "some_other_value"
  # has a new data value been added?
  assert_equal test.new_data, "new_value"
  # or
  expect(test.new_data).to eq "new_value"
end
```

### Testing results
To test the results from a result handler:
```ruby
MyOperation.handling(:a_result, some: "data") do |test|
  assert_equal test.outcome, "everything is as expected"
  # or
  assert_equal test[:outcome], "everything is as expected"
  # or
  expect(test.outcome).to eq "everything is as expected"
  # or
  expect(test[:outcome]).to eq "everything is as expected"
end
```
(Note - although results are stored in the database as a Hash, within your test, the results object is still carried as an OpenStruct, so you can access it using either notation).

### Testing sub-tasks 
```ruby 
MyOperation.handling(:a_sub_task, some: "data") do |test|
  # Test which sub-tasks were called
  assert_includes test.sub_tasks.keys, MySubTask
  # or 
  expect(test.sub_tasks).to include MySubTask
end
```
TODO: I'm still figuring out how to test the data passed to sub-tasks.  And calling a sub-task will actually execute that sub-task, so you need to stub `MySubTask.call` if it's an expensive operation.  

```ruby 
# Sorry, don't know the Minitest syntax for this
@sub_task = double "Operations::Task", results: { some: "answers" }
allow(MySubTask).to receive(:call).and_return(@sub_task)

MyOperation.handling(:a_sub_task, some: "data") do |test|
  expect(test.sub_tasks).to include MySubTask
end
```
### Testing failures 
To test if a handler has failed:
```ruby

expect { MyOperation.handling(:a_failure, some: "data") }.to raise_error(SomeException)
```

If you are using RSpec, you must `require "operations/matchers"` to make the matchers available to your specs.  

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
- [ ] Deal with actions that have forgotten to call `go_to` (probably related to future `pause` functionality)
- [x] Simplify calling sub-tasks (and testing them)
- [ ] Figure out how to stub calling sub-tasks with known results data 
- [ ] Figure out how to test the parameters passed to sub-tasks when they are called
- [ ] Split out the state-management definition stuff from the task class (so you can use it without subclassing Operations::Task)
- [x] Make Operations::Task work in the background using ActiveJob
- [x] Add pause/resume capabilities (for example, when a task needs to wait for user input)
- [x] Add wait for sub-tasks capabilities
- [ ] Add ActiveModel validations support for task parameters
- [ ] Option to change background job queue and priority settings
- [ ] Replace the ActiveJob::Arguments deserialiser with the [transporter](https://github.com/standard-procedure/plumbing/blob/main/lib/plumbing/actor/transporter.rb) from [plumbing](https://github.com/standard-procedure/plumbing)
- [ ] Maybe? Split this out into two gems - one defining an Operation (pure ruby) and another defining the Task (using ActiveJob as part of a Rails Engine)
