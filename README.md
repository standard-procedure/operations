# Operations
Build your business logic operations in an easy to understand format.  

Most times when I'm adding a feature to a complex application, I tend to end up drawing a flowchart.  

"We start here, then we check that option and if it's true then we do this, if it's false then we do that"

In effect, that flowchart is a state machine - with "decision states" and "action states".  And Operations is intended to be a way of designing your ruby class so that flowchart becomes easy to follow.  

## Usage

Here's a simplified example from [Collabor8Online](https://www.collabor8online.co.uk) - in C8O when you download a document, we need to check your access rights, as well as ensuring that the current user has not breached their monthly download limit.  In addition, some accounts have a "filename scrambler" switched on - where the original filename is replaced (which is a feature used by some of our clients on their customers' trial accounts).  

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
         Get the document's download URL and filename and return it as the results of this operation
         DONE
```

We have five states - three of which are decisions, one is an action and one is a result.  

Here's how this would be represented using Operations.  

```ruby
class DownloadDocument < Operations::Task
  data :user
  validates :user, presence: true 
  data :document
  validates :document, presence: true 
  data :use_filename_scrambler, :boolean, default: false
  validates :user_filename_scrambler, presence: true 
  data :filename, :string
  validates :filename, presence: true 

  starts_with :check_authorisation

  decision :check_authorisation do 
    condition { user.can?(:read, document) }
    if_true :check_download_limits 
    if_false :fail, "unauthorised"
  end

  decision :check_download_limits do 
    condition { user.within_download_limits? }
    if_true :check_filename_scrambler 
    if_false :fail, "download_limit_reached"
  end 

  decision :check_filename_scrambler do 
    condition { use_filename_scrambler? }
    if_true :scramble_filename 
    if_false :prepare_download 
  end 

  action :scramble_filename do 
    self.filename = "#{Faker::Lorem.word}#{File.extname(document.filename.to_s)}"
    go_to :prepare_download
  end

  completed :prepare_download do |results|
    results[:filename] = filename || document.filename.to_s
  end
end
```

And you would use it like so:
```ruby
class DownloadsController < ApplicationController 
  def show 
    @document = Document.includes(:account).find(params[:id])
    @filename = DownloadDocument.call(user: Current.user, document: @document, use_filename_scrambler: true)[:filename]
    send_data @document.contents.download, filename: @filename, disposition: "attachment"
  rescue Operations::Failed => failure 
    render action: "error", message: failure.message, status: 401
  end
end
```

OK - so that's a pretty longwinded way of performing a simple task.  But as the number of states and decisions grow, mapping out the sequence in simple steps, with a clear direction of travel from one state to the next becomes incredibly useful.  

And there's one extra trick up our sleeve. 

Any task can be marked as running in the background.  

When this happens, the task is scheduled to run in ActiveJob, as a background task.  But more importantly, each _state transition_ is handled as an individual task.  

Returning to Collabor8Online, our download process is much more involved than the simple example above.  If the file is an AutoCAD file, we upload it to AutoCAD's conversion service, then, once the conversion has completed, we use their 3D Viewer component to display it.  If the file is a .docx file, we download a local copy, perform a mail-merge on it, using merge data that is specific to the current logged in user, then allow the user to download that customised document.  As you can imagine, sometimes, these individual steps may take a while to complete.  So marking the entire DownloadDocument task as a background operation will schedule an ActiveJob for each state, which, once completed, then schedules another job for the next state transition.  That way, the entire sequence of transitions may take several minutes, but no individual stage will cause ActiveJob to time out (or starve the active job process of workers).  And the task itself can be tracked through its status - either using a TurboStream to update progress in the user-interface - or, if the task is not too long, we can wait for completion.  

```ruby
class DownloadsController < ApplicationController 
  def show 
    @document = Document.includes(:account).find(params[:id])
    @download = SlightlyLongerDocumentDownload.start(user: Current.user, document: @document, use_filename_scrambler: true)
    @download.wait(30.seconds)
    @filename = @download.filename
    send_data @document.contents.download, filename: @filename, disposition: "attachment"
  rescue Operations::Failed => failure 
    render action: "error", locals: {message: failure.message}, status: 401
  rescue Timeout 
    render action: "error", locals: {message: "Download timed out"}, status: 403
  end
end
```


## Installation
Add this line to your application's Gemfile:

```ruby
gem "standard_procedure_operations"
```
## License
The gem is available as open source under the terms of the [LGPL License](/LICENSE).  This may or may not make it suitable for your needs
