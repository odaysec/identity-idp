module Idv
  class StepInfo
    include ActiveModel::Validations

    attr_reader :key, :controller, :action, :next_steps, :preconditions, :undo_step
    attr_reader :controller_module

    validates :controller, presence: true
    validates :action, presence: true
    validates :controller_module, presence: true
    validate :next_steps_validation, :preconditions_validation, :undo_step_validation

    def initialize(
      key:,
      controller:,
      next_steps:,
      preconditions:,
      undo_step:,
      action: :show,
      controller_module: 'idv'
    )
      @key = key
      @controller = controller
      @next_steps = next_steps
      @preconditions = preconditions
      @undo_step = undo_step
      @action = action
      @controller_module = controller_module

      raise ArgumentError unless valid?
    end

    def next_steps_validation
      unless next_steps.is_a?(Array)
        errors.add(:next_steps, type: :invalid_argument, message: 'next_steps must be an Array')
      end
    end

    def preconditions_validation
      unless preconditions.is_a?(Proc)
        errors.add(:preconditions, type: :invalid_argument, message: 'preconditions must be a Proc')
      end
    end

    def undo_step_validation
      unless undo_step.is_a?(Proc)
        errors.add(:undo_step, type: :invalid_argument, message: 'undo_step must be a Proc')
      end
    end
  end
end
