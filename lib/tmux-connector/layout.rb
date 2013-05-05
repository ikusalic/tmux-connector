module TmuxConnector
  class Layout
    attr_reader :merged_groups
    attr_reader :windows

    def initialize(config, groups, merge_rules)
      @config = config
      @groups = groups
      @merge_rules = merge_rules

      @windows = []

      generate
    end

  private

      def generate()
        config = process_layout_config

        @merged_groups = {}
        @merge_rules.each do |k, v|
          @merged_groups[v] ||= []
          @merged_groups[v].concat @groups[k]
        end

        merged_groups.each do |name, hosts|
          add_group_to_layout name, hosts, (config[name] || config['default'])
        end
      end

      def process_layout_config()
        config = { 'default' => @config['default'] }
        @config['group-layouts'].each { |k, v| config[k] = v }
        return config
      end

      def add_group_to_layout(group_name, hosts, config)
        if config['custom']
          n = config['custom']['max-horizontal'] * config['custom']['max-vertical']
        else
          n = config['tmux']['max-panes']
        end

        hosts.each_slice(n).with_index do |arr, i|
          window = {
            name: "#{ group_name }##{ i + 1 }",
            group_name: group_name,
            group_index: i + 1
          }

          if config['tmux']
            window[:tmux] = config['tmux']['layout']
            window[:panes] = arr
          else
            window[:flow] = config['custom']['panes-flow']

            if window[:flow] == 'horizontal'
              window[:panes] = arr.each_slice(config['custom']['max-horizontal']).to_a
            else
              window[:panes] = arr.each_slice(config['custom']['max-vertical']).to_a
            end
          end

          @windows << window
        end
      end
  end
end
