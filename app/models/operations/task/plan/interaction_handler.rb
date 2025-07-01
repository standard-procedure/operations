class Operations::Task::Plan::InteractionHandler
  def initialize name, klass, &implementation
    @legal_states = []
    build_method_on klass, name, self, implementation
  end
  attr_reader :legal_states

  def when *legal_states
    @legal_states = legal_states.map(&:to_s).freeze
  end

  private def build_method_on klass, name, handler, implementation
    klass.define_method name.to_sym do |*args|
      raise Operations::InvalidState.new("#{klass}##{name} cannot be called in #{current_state}") if handler.legal_states.any? && !handler.legal_states.include?(current_state.to_s)
      Rails.logger.debug { "interaction #{name} with #{self}" }
      instance_exec(*args, &implementation)
      wake_up!
    end
  end
end
