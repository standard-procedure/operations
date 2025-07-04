module Operations::Task::Testing
  extend ActiveSupport::Concern

  class_methods do
    def test state, **attributes
      create!(current_state: state, **attributes).tap do |task|
        task.call_handler
      end
    end
  end
end
