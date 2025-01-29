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
  starts_with :authorised?

  decision :authorised? do
    if_true :within_download_limits?
    if_false { fail_with "unauthorised" }
  end

  decision :within_download_limits? do
    if_true :use_filename_scrambler?
    if_false { fail_with "download_limit_reached" }
  end

  decision :use_filename_scrambler? do
    condition { use_filename_scrambler }
    if_true :scramble_filename
    if_false :return_filename
  end

  action :scramble_filename do
    self.filename = "#{Faker::Lorem.word}#{File.extname(document.filename.to_s)}"
    go_to :return_filename
  end

  result :return_filename do |results|
    results.filename = filename || document.filename.to_s
  end

  private def authorised?(data) = data.user.can?(:read, data.document)
  private def within_download_limits?(data) = data.user.within_download_limits?
end
```

The five states are represented as three [decision](#decisions) handlers, one [action](#actions) handler and a [result](#results) handler.  

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
Again, instead of using a block in the action handler, you could provide a method to do the work.

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
After this result handler has executed, the task will then be marked as `completed?`, the task's state will be `ready_to_party` and `results.invited_friends` will contain an array of the people you sent invitations to.  

If you don't have any meaningful results, you can omit the block on your result handler.  
```ruby
result :go_to_work
```
In this case, the task will be marked as `completed?`, the task's state will be `go_to_work` and `results` will be empty.  

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

Within handlers implemented as blocks, you can read the data directly - for example, `condition { use_filename_scrambler }` from the `use_filename_scrambler?` decision shown earlier.  If you want to modify a value, or add a new one, you must use `self` - `self.my_data = "something important"`.  This is because the data is carried using a [DataCarrier](/app/models/operations/task/data_carrier.rb) object and `instance_eval` is used within your block handlers.  This also means that block handlers must use `task.method` to access methods or data on the task object itself (as you are not actually within the context of the task object itself).  The exceptions are the `go_to` and `fail_with` methods which the data carrier forwards to the task.  

Handlers can alternatively be implemented as methods on the task itself.  This means that they are executed within the context of the task and can methods and variables belonging to the task.  Each handler method receives a `data` parameter which is the data carrier for that task.  Individual items can be accessed as a hash - `data[:my_item]` - or as an attribute - `data.my_item`.  

The final `results` data from any `result` handlers is stored, along with the task, in the database, so it can be examined later.  It is accessed as an OpenStruct that is encoded into JSON.  But any ActiveRecord models are translated using a [GlobalID](https://github.com/rails/globalid) using [ActiveJob::Arguments](https://guides.rubyonrails.org/active_job_basics.html#supported-types-for-arguments).  Be aware that if you do store an ActiveRecord model into your `results` and that model is later deleted from the database, your task's `results` will be unavailable, as the `GlobalID::Locator` will fail when it tries to load the record.  The data is not lost though - if the deserialisation fails, the routine will return the JSON string as `results.raw_data`.

### Failures and exceptions

If any handlers raise an exception, the task will be terminated. It will be marked as `failed?` and the `results` hash will contain `results.exception_message`, `results.exception_class` and `results.exception_backtrace` for the exception's message, class name and backtrace respectively.  

You can also stop a task at any point by calling `fail_with message`.  This will mark the task as `failed?` and the `reeults` has will contain `results.failure_message`.

### Task life-cycle and the database

There is an ActiveRecord migration that creates the `operations_tasks` table.  Use `bin/rails app:operations:install:migrations` to copy it to your application.  

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

## Installation
Add this line to your application's Gemfile:

```ruby
gem "standard_procedure_operations"
```

Run `bundle install`, copy and run the migrations to add the tasks table to your database:

```sh
bin/rails app:operations:install:migrations 
bin/rails db:migrate
```

Then create your own operations by inheriting from `Operations::Task`.

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

## License
The gem is available as open source under the terms of the [LGPL License](/LICENSE).  This may or may not make it suitable for your needs.
