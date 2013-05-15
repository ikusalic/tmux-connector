require_relative '../persistence_handler'


module TmuxConnector
  class List
    def initialize(args)
    end

    def run()
      sessions_data = TmuxConnector.list_sessions suppress_error: true
      if sessions_data.empty?
        puts "No sessions found."
      else
        puts "sessions:"
        puts sessions_data.to_yaml
        puts "-" * 20
      end
    end
  end
end
