require 'spec_helper'

describe 'configuration' do
  before do
    # Backup connection and configs
    @backup_conn = Standby.instance_variable_get :@standby_connections
    if Standby.version_gte?('7.0')
      @backup_config = ActiveRecord::Base.configurations.configs_for.map do |config|
        [config.env_name, config.configuration_hash]
      end.to_h
    else
      @backup_config = ActiveRecord::Base.configurations.dup
    end
    @backup_disabled = Standby.disabled
    @backup_conn.each_key do |klass_name|
      Object.send(:remove_const, klass_name) if Object.const_defined?(klass_name)
    end
    Standby.instance_variable_set :@standby_connections, {}
  end

  after do
    # Restore connection and configs
    Standby.instance_variable_set :@standby_connections, @backup_conn
    ActiveRecord::Base.configurations = @backup_config
    Standby.disabled = @backup_disabled
  end

  it 'raises error if standby configuration not specified' do
    if Standby.version_gte?('7.0')
      ActiveRecord::Base.configurations = @backup_config.merge({ 'test_standby' => {} })
    else
      ActiveRecord::Base.configurations['test_standby'] = nil
    end

    expect { Standby.on_standby { User.count } }.to raise_error(Standby::Error)
  end

  it 'connects to primary if standby configuration is disabled' do
    if Standby.version_gte?('7.0')
      ActiveRecord::Base.configurations = @backup_config.merge({ 'test_standby' => {} })
    else
      ActiveRecord::Base.configurations['test_standby'] = nil
    end
    Standby.disabled = true

    expect(Standby.on_standby { User.count }).to be 2
  end
end
