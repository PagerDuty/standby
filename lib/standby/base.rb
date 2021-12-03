module Standby
  class Base
    def initialize(target, allow_replica_read_in_transaction = false)
      @target = decide_with(target, allow_replica_read_in_transaction)
    end

    def run(&block)
      run_on @target, &block
    end

  private

    def decide_with(target, allow_replica_read_in_transaction)
      if Standby.disabled || target == :primary || (!allow_replica_read_in_transaction && inside_transaction?)
        :primary
      elsif target == :null_state
        :standby
      elsif target.present?
        "standby_#{target}".to_sym
      else
        raise Standby::Error.new('on_standby cannot be used with a nil target!')
      end
    end

    def inside_transaction?
      open_transactions = run_on(:primary) { ActiveRecord::Base.connection.open_transactions }
      open_transactions > Standby::Transaction.base_depth
    end

    def run_on(target)
      backup = Thread.current[:_standby] # Save for recursive nested calls
      Thread.current[:_standby] = target
      yield
    ensure
      Thread.current[:_standby] = backup
    end
  end
end
