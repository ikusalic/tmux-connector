require_relative '../session'
require_relative '../tmux_handler'


module TmuxConnector
  class Send
    attr_reader :commands
    attr_reader :group_filter
    attr_reader :name
    attr_reader :server_filter
    attr_reader :session
    attr_reader :verbose
    attr_reader :window

    def initialize(args)
      @name = args['<session-name>']
      @verbose = args['--verbose']

      load_commands args

      @server_filter = Regexp.new(args['--server-filter']) rescue nil
      @group_filter = Regexp.new(args['--group-filter']) rescue nil

      @server_filter ||= Regexp.new(args['--filter']) rescue nil
      @group_filter ||= Regexp.new(args['--filter']) rescue nil

      @window = args['--window']

      @session = Session.load_by_name args['<session-name>']
    end

    def run()
      session.tmux_session.send_commands(commands, server_filter, group_filter, window, verbose)
    end

  private
      
      def load_commands(args)
        if args['<command>']
          @commands = args['<command>']
        else
          file = File.expand_path args['--command-file']
          raise "command file (#{ file }) not found" unless File.exist? file
          @commands = open(file) { |f| f.read }
        end
      end
  end
end
