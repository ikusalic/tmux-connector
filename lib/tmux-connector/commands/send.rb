require_relative '../session'
require_relative '../tmux_handler'


module TmuxConnector
  class Send
    attr_reader :commands
    attr_reader :filter_predicate
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

      process_server_filter args['--server-filter'] rescue raise "error parsing server filter ('#{ args['--server-filter'] }')"

      @group_filter = Regexp.new(args['--group-filter']) rescue nil

      @server_filter ||= Regexp.new(args['--filter']) rescue nil
      @group_filter ||= Regexp.new(args['--filter']) rescue nil

      @window = args['--window']

      @session = Session.load_by_name args['<session-name>']
    end

    def run()
      opts = {
        verbose: verbose,
        filter_predicate: filter_predicate
      }

      session.tmux_session.send_commands(commands, server_filter, group_filter, window, opts)
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

      def process_server_filter(raw_filter)
        return unless raw_filter

        str_filter, str_predicate = raw_filter.split(' :: ')

        @server_filter = (Regexp.new(str_filter) rescue nil)

        return if str_predicate.nil?

        predicate_parts = parse_predicate(str_predicate)
        @filter_predicate = build_predicate(predicate_parts)
      end

      def parse_predicate(str_predicate)
        return nil if str_predicate.nil?

        predicate_delimiter = /;\s*/
        interval_regex = /(?<start>[\[<])(?<first>[^,]*),\s*(?<second>[^\]>]*)(?<end>[\]>])/

        return str_predicate.split(predicate_delimiter).map do |element|
            m = element.match(interval_regex)
            Hash[ m.names.map(&:to_sym).zip(m.captures) ] rescue element
        end
      end

      def build_predicate(parts)
        return lambda do |sort_value|
          return false if sort_value.nil?

          numeric_comparison = sort_value.instance_of? Fixnum

          intervals, elements = parts.partition { |e| e.instance_of? Hash }

          elements = elements.map(&:to_i) if numeric_comparison
          return true if elements.include? sort_value

          intervals.each do |interval|
            first = interval[:first]
            second = interval[:second]

            matches = true

            unless first.empty?
              first = Integer(first, 10) if numeric_comparison

              if interval[:start] == '['
                matches &&= sort_value >= first
              elsif interval[:start] == '<'
                matches &&= sort_value > first
              end
            end

            unless second.empty?
              second = Integer(second, 10) if numeric_comparison

              if interval[:end] == ']'
                matches &&= sort_value <= second
              elsif interval[:end] == '>'
                matches &&= sort_value < second
              end
            end

            return true if matches
          end

          return false
        end
      end
  end
end
