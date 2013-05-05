require 'yaml'


module TmuxConnector
  DEFAULT_CONFIG_FILE = 'lib/tmux-connector/default_config.yml'

  def self.get_config(config_file)
    config = read_config config_file
    process_config! config
    validate_config config
    return config
  end

  def self.read_config(config_file)
    full_path = File.expand_path config_file
    raise "configuration file (#{config_file}) not found" unless File.exist? full_path
    config = YAML.load_file full_path

    return config
  end

  def self.process_config!(config)
    config['regex'] = Regexp.new config['regex']
    if config['name']
      c = config['name']
      c['regex-ignore-parts'] ||= []
      c['separator'] ||= '-'
      c['prefix'] ||= ''
    end

    process_layout config['layout']['default']
    config['layout']['group-layouts'].each { |k, v| process_layout v }
  end

  def self.process_layout(config)
    if config['tmux']
      config['tmux']['max-panes'] ||= 9
    else
      config['custom']['panes-flow'] ||= 'horizontal'
    end
  end

  def self.validate_config(config)
    # TODO
  end
end
