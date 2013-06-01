require 'yaml'


module TmuxConnector
  DEFAULT_CONFIG_FILE = 'lib/tmux-connector/default_config.yml'

  def self.get_config(config_file)
    config = read_config config_file
    process_config! config
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
    config['reject-regex'] = Regexp.new(config['reject-regex']) if config['reject-regex']
    if config['name']
      c = config['name']
      c['regex-ignore-parts'] ||= []
      c['separator'] ||= '-'
      c['prefix'] ||= ''
    end

    layout = config['layout'] ||= {}

    if layout['default'].nil?
      layout['default'] = {
        'tmux' => { 'layout' => 'tiled' }
      }
    end
    expand_layout layout['default']

    if layout['group-layouts']
      layout['group-layouts'].each { |k, v| expand_layout v }
    end
  end

  def self.expand_layout(config)
    if config['tmux']
      config['tmux']['max-panes'] ||= 9
    else
      config['custom']['panes-flow'] ||= 'horizontal'
    end
  end
end
