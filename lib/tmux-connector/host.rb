module TmuxConnector
  QUICK_GROUP_ID = 'quick_group_id'

  class Host
    attr_accessor :sort_value

    attr_reader :count
    attr_reader :display_name
    attr_reader :group_id
    attr_reader :ssh_name

    def initialize(name, config)
      @ssh_name = name

      groups = name.match(config['regex'])[1..-1]
      @display_name = create_display_name groups, config
      @sort_value = config['regex-parts-to']['sort-by'].map { |i| groups[i] }.join '-'
      @group_id = config['regex-parts-to']['group-by'].map { |i| groups[i] }.join '-'

      check_range! config['group-ranges']
      @count = get_count config
    end

    def to_s()
      return "<host::#{ display_name }>"
    end

  private

      def check_range!(ranges)
        return if ranges.nil?

        range = ranges[group_id] || ranges[TmuxConnector::QUICK_GROUP_ID]
        if range
          a, b = range.map(&:to_s)
          x = sort_value

          numbers_only = [a, b, x].all? { |e| e =~ /^[-+]?[0-9]*$/ }
          a, b, x = [a, b, x].map { |e| Integer(e, 10) rescue nil } if numbers_only

          raise if a && x < a
          raise if b && x > b
        end
      end

      def create_display_name(groups, config)
        if config['name']
          parts = []
          groups.each_with_index do |e, i|
            parts << e unless config['name']['regex-ignore-parts'].include? i
          end

          return config['name']['prefix'] + parts.join(config['name']['separator'])
        end

        return ssh_name
      end

      def get_count(config)
        multiple = config['multiple-hosts']
        return 1 if multiple.nil?

        [ multiple['regexes'], multiple['counts'] ].transpose.each do |re, n|
          return n if ssh_name.match re
        end

        return 1
      end
  end

  class FakeHost
    attr_reader :count
    attr_reader :display_name
    attr_reader :group_id
    attr_reader :sort_value
    attr_reader :ssh_name

    def initialize(name, count)
      @display_name = @group_id = @ssh_name = name
      @count = count

      @sort_value = nil
    end

    def to_s()
      return "<fake-host::#{ display_name }-#{ count }>"
    end
  end
end
