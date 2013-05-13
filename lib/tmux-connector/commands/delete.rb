require_relative '../persistence_handler'


module TmuxConnector
  class Delete
    attr_reader :delete_all
    attr_reader :name

    def initialize(args)
      @name = args['<session-name>']
      @delete_all = args['--all']
    end

    def run()
      if name
        TmuxConnector.delete_session name
        TmuxConnector.delete_tmux_session name
      elsif delete_all
        TmuxConnector.delete_all
        TmuxConnector.delete_all_tmux_sessions
      end
    end
  end
end
