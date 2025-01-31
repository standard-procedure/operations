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

    if_true :within_download_limits?
    if_false { fail_with "unauthorised" }
  end

  decision :within_download_limits? do
    inputs :user

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

  private def authorised?(data) = data.user.can?(:read, data.document)
  private def within_download_limits?(data) = data.user.within_download_limits?
end
```

The five states are represented as three [decision](#decisions) handlers, one [action](#actions) handler and a [result](#results) handler.  

The task also declares that it requires a `user`, `document` and `use_filename_scrambler` parameter to be provided, and also declares its initial state - `authorised?`.  

### Decisions
A decision handler evaluates a condition, then changes state depending upon if the result is true or false. 

It's up to you whether you define the condition as a block, as part of the decision handler, or as a method on the task object.  

```ruby
decision :is_it_the_weekend? do 
  condition { Date.today.wday.in? [0, 6] }

  if_true :have_a_party 
  if_false :go_to_work
end
```
Or
```ruby
decision :is_it_the_weekend? do 
  if_true :have_a_party 
  if_false :go_to_work
end

def is_it_the_weekend?(data)
  Date.today.wday.in? [0, 6]
end
```

A decision can also mark a failure, which will terminate the task.  
```ruby
decision :authorised? do 
  condition { user.administrator? }
  if_true :do_some_work 
  if_false { fail_with "Unauthorised" }
end
```

You can specify the data that is required for a decision handler to run by specifying `inputs` and `optionals`:
```ruby
decision :authorised? do 
  inputs  :user 
  optionals :override

  condition { override || user.administrator? }

  if_true :do_some_work 
  if_false { fail_with "Unauthorised" }
end
```
In this case, the task will fail if there is no `user` specified.  However, `override` is optional (and in fact the `optional` method is just there to help you document your operations).

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
You can specify the required and optional data for your action handler within the block.  `optional` is decorative and to help with your documentation.  Ensure you call `inputs` at the start of the block.  

```ruby 
action :have_a_party do
  inputs :task 
  optional :music 

  self.food = task.buy_some_food_for(number_of_guests)
  self.beer = task.buy_some_beer_for(number_of_guests)
  self.music ||= task.plan_a_party_playlist
  go_to :send_invitations
end
```

Again, instead of using a block in the action handler, you could provide a method to do the work.  However, you cannot specify `inputs` or `optional` data when using a method.  

```ruby
action :have_a_party

def have_a_party(data)
  data.food = buy_some_food_for(data.number_of_guests)
  data.beer = buy_some_beer_for(data.number_of_guests)
  data.music = plan_a_party_playlist
  go_to :send_invitations
end
```
Note that when using a method you need to refer to the `data` parameter directly, when using a block, you need to refer to the `task` - see the section on "[Data](#data-and-results)" for more information.

Do not forget to call `go_to` from your action handler, otherwise the operation will just stop whilst still being marked as in progress.  

### Results
A result handler marks the end of an operation, optionally returning some results.  You need to copy your desired results from your [data](#data-and-results) to your results object.  This is so only the information that matters to you is stored in the database (as many operations may have a large set of working data).  

There is no method equivalent to a block handler.  

```ruby
action :send_invitations do 
  self.invited_friends = (0..number_of_guests).collect do |i|
    friend = friends.pop
    FriendsMailer.with(recipient: friend).party_invitation.deliver_later
    friend 
  end
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
  inputs :number_of_guests
  self.invited_friends = (0..number_of_guests).collect do |i|
    friend = friends.pop
    FriendsMailer.with(recipient: friend).party_invitation.deliver_later
    friend 
  end
  go_to :ready_to_party
end

result :ready_to_party do |results|
  inputs :invited_friends 

  results.invited_friends = invited_friends
end

### Calling an operation
You would use the earlier [PrepareDocumentForDownload](spec/examples/prepare_document_for_download_spec.rb) operation in a controller like this:

```ruby
class DownloadsController < ApplicationController 
  def show 
    @document = Document.includes(:account).find(params[:id])
    @task = PrepareDocumentForDownload.call(user: Current.user, document: @document, use_filename_scrambler: @document.account.use_filename_scrambler?)
    if @task.completed?
      @filename = @task.results.filename
      send_data @document.contents, filename: @filename, disposition: "attachment"
    else
      render action: "error", message: @task.results.failure_message, status: 401
    end
  end
end
```

OK - so that's a pretty longwinded way of performing a simple task.  But, in Collabor8Online, the actual operation for handling downloads has over twenty states, with half of them being decisions (as there are a number of feature flags and per-account configuration options).  When you get to complex decision trees like that, being able to lay them out as state transitions becomes invaluable.  

### Data and results
Each operation carries its own, mutable, data for the duration of the operation.  This is provided when you `call` the operation to start it and is passed through to each decision, action and result.  This data is transient and not stored in the database. If you modify the data then that modification is passed on to the next handler.  

For example, in the [DownloadsController](#calling-an-operation) shown above, the `user`, `document` and `use_filename_scrambler` are set within the data object when the operation is started.  But if the `scramble_filename` action is called, it generates a new filename and adds that to the data object as well.  Finally the `return_filename` result handler then returns either the scrambled or the original filename to the caller. 

Within handlers implemented as blocks, you can read the data directly - for example, `condition { use_filename_scrambler }` from the `use_filename_scrambler?` decision shown earlier.  If you want to modify a value, or add a new one, you must use `self` - `self.my_data = "something important"`.  

This is because the data is carried using a [DataCarrier](/app/models/operations/task/data_carrier.rb) object and `instance_eval` is used within your block handlers.  

This also means that block handlers must use `task.method` to access methods or data on the task object itself (as you are not actually within the context of the task object itself).  The exceptions are the `go_to` and `fail_with` methods which the data carrier forwards to the task.  

Handlers can alternatively be implemented as methods on the task itself.  This means that they are executed within the context of the task and can methods and variables belonging to the task.  Each handler method receives a `data` parameter which is the data carrier for that task.  Individual items can be accessed as a hash - `data[:my_item]` - or as an attribute - `data.my_item`.  

The final `results` data from any `result` handlers is stored, along with the task, in the database, so it can be examined later.  It is a Hash that is encoded into JSON with any ActiveRecord models translated using a [GlobalID](https://github.com/rails/globalid) (this uses [ActiveJob::Arguments](https://guides.rubyonrails.org/active_job_basics.html#supported-types-for-arguments) so works the same way as passing models to ActiveJob).  

Be aware that if you do store an ActiveRecord model into your `results` and that model is later deleted from the database, your task's `results` will be unavailable (as `GlobalID::Locator` will fail when it tries to load the record).  The data is not lost though - if the deserialisation fails, the routine will return the JSON string as `results.raw_data`.

### Failures and exceptions
If any handlers raise an exception, the task will be terminated. It will be marked as `failed?` and the `results` hash will contain `results[:failure_message]`, `results[:exception_class]` and `results[:exception_backtrace]` for the exception's message, class name and backtrace respectively.  

You can also stop a task at any point by calling `fail_with message`.  This will mark the task as `failed?` and the `reeults` has will contain `results[:failure_message]`.

### Task life-cycle and the database
There is an ActiveRecord migration that creates the `operations_tasks` table.  Use `bin/rails operations:install:migrations` to copy it to your application, then run `bin/rails db:migrate` to add the table to your application's database.  

When you `call` a task, it is written to the database.  Then whenever a state transition occurs, the task record is updated.  

This gives you a number of possibilities: 
- you can access the results (or error state) of a task after it has completed
- you can use [TurboStream broadcasts](https://turbo.hotwired.dev/handbook/streams) to update your user-interface as the state changes - see "[status messages](#status-messages)" below
- tasks can run in the background (using ActiveJob) and other parts of your code can interact with them whilst they are in progress - see "[background operations](#background-operations-and-pauses)" below
- the tasks table acts as an audit trail or activity log for your application

However, it also means that your database table could fill up with junk that you're no longer interested in.  Therefore you can specify the maximum age of a task and, periodically, clean old tasks away.  Every task has a `delete_at` field that, by default, is set to `90.days.from_now`.  This can be changed by calling `Operations::Task.delete_after 7.days` (or whatever value you prefer).  Then, run a cron job (once per day) that calls `Operations::Task.delete_expired`, removing any tasks whose `deleted_at` date has passed.  

### Status messages
Documentation coming soon.  

### Child tasks
Coming soon.  

### Background operations and pauses
Coming soon.  

## Testing
Because operations are intended to model long, complex, flowcharts of decisions and actions, it can be a pain coming up with the combinations of inputs to test every path through the sequence.  

Instead, you can test each state handler in isolation.  As the handlers are state-less, we can simulate calling one by creating a task object and then calling the appropriate handler with the data that it expects.  This is done by calling `handling`, which yields a `test` object with outcomes from the handler that we can inspect

To test if we have moved on to another state (for actions or decisions):
```ruby
MyOperation.handling(:an_action_or_decision, some: "data") do |test|
  assert_equal test.next_state, "new_state"
  # or
  expect(test).to have_moved_to "new_state"
end
```
To test if some data has been set or modified (for actions):
```ruby
MyOperation.handling(:an_action, existing_data: "some_value") do |test|
  # has a new data value been added?
  assert_equal test.new_data, "new_value"
  # or
  expect(test.new_data).to eq "new_value"
  # has an existing data value been modified?
  assert_equal test.existing_data, "some_other_value"
  # or
  expect(test.existing_data).to eq "some_other_value"
end
```
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

To test if a handler has failed:
```ruby
MyOperation.handling(:a_failure, some: "data") do |test|
  assert_equal test.failure_message, "oh dear"
  # or
  expect(test).to have_failed_with "oh dear"
end
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
    if_true :live_like_theres_no_tomorrow 
    if_false :rest_and_recuperate
  end 

  result :live_like_theres_no_tomorrow 
  result :rest_and_recuperate

  def am_i_awake? = (7..23).include?(Time.now.hour)
end
```
Step 4: If you're using RSpec for testing, add `require "operations/matchers" to your "spec/rails_helper.rb" file.

## License
The gem is available as open source under the terms of the [LGPL License](/LICENSE).  This may or may not make it suitable for your needs.

## Roadmap

- [ ] Specify inputs (required and optional) per-state, not just at the start
- [ ] Always raise errors instead of just recording a failure (will be useful when dealing with sub-tasks)
- [ ] Simplify calling sub-tasks (and testing the same)
- [ ] Split out the state-management definition stuff from the task class (so you can use it without subclassing Operations::Task)
- [ ] Make Operations::Task work in the background using ActiveJob
- [ ] Add pause/resume capabilities (for example, when a task needs to wait for user input)
- [ ] Add wait for sub-tasks capabilities
