module Operations::Task::InputValidation
  def inputs(*names) = @required_inputs = names.map(&:to_sym)

  def optional(*names) = @optional_inputs = (optional_inputs + names.map(&:to_sym))
  alias_method :data, :optional

  def optional_inputs = @optional_inputs ||= []

  def required_inputs = @required_inputs ||= []

  def required_inputs_are_present_in?(hash) = missing_inputs_from(hash).empty?

  def missing_inputs_from(hash) = (required_inputs - hash.keys.map(&:to_sym))

  def validate_inputs! hash
    raise ArgumentError, "Missing inputs: #{missing_inputs_from(hash).join(", ")}" unless required_inputs_are_present_in?(hash)
  end
end
