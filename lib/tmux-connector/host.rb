module TmuxConnector
  class Host
    attr_reader :ssh_name
    attr_reader :display_name
    attr_reader :group_id
    attr_reader :sort_value

    def initialize(name, config)
      @ssh_name = name

      groups = name.match(config['regex'])[1..-1]
      @display_name = create_display_name groups, config
      @sort_value = config['regex-parts-to']['sort-by'].map { |i| groups[i] }.join '-'
      @group_id = config['regex-parts-to']['group-by'].map { |i| groups[i] }.join '-'
    end

    def to_s()
      return "<host::#{ display_name }>"
    end

  private

      def create_display_name groups, config
        if config['name']
          parts = []
          groups.each_with_index do |e, i|
            parts << e unless config['name']['regex-ignore-parts'].include? i
          end

          return config['name']['prefix'] + parts.join(config['name']['separator'])
        end

        return @ssh_name
      end
  end
end
