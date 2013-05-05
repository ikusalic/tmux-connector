require_relative '../persistence_handler'


module TmuxConnector
  class Delete
    attr_reader :name

    def initialize(args)
      @name = args['<session-name>']
    end

    def run()
      TmuxConnector.delete_session name
    end
  end
end
