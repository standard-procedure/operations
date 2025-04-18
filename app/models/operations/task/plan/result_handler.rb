class Operations::Task::Plan::ResultHandler
  def initialize name, inputs = [], optional = [], &handler
    @name = name.to_sym
    @required_inputs = inputs
    @optional_inputs = optional
    @handler = handler
  end

  def immediate? = true

  def call(task, data)
    results = OpenStruct.new
    data.instance_exec(results, &@handler) unless @handler.nil?
    data.complete(results)
  end
end
