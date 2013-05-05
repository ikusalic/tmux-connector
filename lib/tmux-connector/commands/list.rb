require_relative '../persistence_handler'


module TmuxConnector
  class List
    def initialize(args)
    end

    def run()
      sessions_data = TmuxConnector.list_sessions
      puts "sessions:"
      puts sessions_data.to_yaml
      puts "-" * 20
    end
  end
end
