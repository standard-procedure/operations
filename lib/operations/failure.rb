class Operations::Failure < Operations::Error
  def initialize message, task = nil
    super(message)
    @task = task
  end
  attr_reader :task
end
