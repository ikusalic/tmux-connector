require_relative '../session'


module TmuxConnector
  class Resume
    attr_reader :name
    attr_reader :session

    def initialize(args)
      @session = Session.load_by_name args['<session-name>']
    end

    def run()
      session.start
    end
  end
end
