require_relative 'layout'
require_relative 'persistence_handler'
require_relative 'tmux_handler'


module TmuxConnector
  class Session
    def self.load_by_name(name)
      return TmuxConnector.load_session name
    end

    attr_reader :args
    attr_reader :config
    attr_reader :name
    attr_reader :merge_rules
    attr_reader :tmux_session
    attr_reader :windows

    def initialize(config, args, groups, merge_rules)
      @config = config
      @args = args
      @merge_rules = merge_rules

      @name = TmuxConnector.get_new_session_name(args)
      @windows = Layout.new(config['layout'], groups, merge_rules).windows

      @tmux_session = TmuxSession.new self
    end

    def start()
      tmux_session.start_session
    end

    def save()
      TmuxConnector.save_session name, self
    end
  end
end
