class Operations::Agent::InteractionHandler
  def initialize name, klass, &implementation
    @legal_states = []
    build_method_on klass, name, self, implementation
  end
  attr_reader :legal_states

  def when *legal_states
    @legal_states = legal_states.map(&:to_sym).freeze
  end

  private def call(task, data, *args)
    data.instance_exec(*args, &@implementation)
  end

  private def build_method_on klass, name, handler, implementation
    klass.define_method name.to_sym do |*args|
      raise Operations::InvalidState.new("#{klass}##{name} cannot be called in #{state}") if !handler.legal_states.empty? && !handler.legal_states.include?(state.to_sym)
      Rails.logger.debug { "#{data[:task]}: interaction #{name} with #{data}" }
      carrier_for(data).tap do |data|
        data.instance_exec(*args, &implementation)
        record_state_transition! data: data
        perform
      end
    rescue => ex
      record_exception(ex)
      raise ex
    end
  end
end
