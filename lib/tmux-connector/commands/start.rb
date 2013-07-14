require_relative '../config_handler'
require_relative '../host'
require_relative '../session'
require_relative '../ssh_config_parser'


module TmuxConnector
  class Start
    attr_reader :config
    attr_reader :hosts
    attr_reader :groups
    attr_reader :merge_rules
    attr_reader :session

    def initialize(args)
      if args['<config-file>']
        @config = TmuxConnector.get_config args['<config-file>']
      elsif args['--quick-session']
        @config = quick_session_to_config args['--quick-session']
      end

      ssh_hostnames = SSHConfig.get_hosts(args['--ssh-config'], config['reject-regex'])
      @hosts = ssh_hostnames.reduce([]) do |acc, name|
        ( acc << Host.new(name, config) ) rescue nil
        acc
      end
      raise "no hosts matching given configuration found, check your configuration" if hosts.empty?

      generate_groups
      generate_merge_rules

      @session = Session.new config, args, groups, merge_rules
    end

    def run()
      session.save
      session.start
    end

  private

      def quick_session_to_config(quick_args)
        quick_regex = /(?<regex>.+)\[\[(?<first>[^,]*),\s*(?<second>[^\]]*)\]\]( :: (?<args>.+))?/
        str_regex, first, last, additiona_args = quick_args.match(quick_regex)[1 .. -1]

        first = "" if first =~ /^\s*$/
        second = "" if second =~ /^\s*$/

        conf = generate_fake_config str_regex
        TmuxConnector.process_config! conf
        apply_additional_arguments! conf, additiona_args

        conf['group-ranges'] = {
          TmuxConnector::QUICK_GROUP_ID => [first, last]
        }

        return conf
      rescue
        raise 'quick session argument parsing failed'
      end

      def generate_fake_config(str_regex)
        return {
          'regex' => "(#{ str_regex })(.+)",
          'regex-parts-to' => {
            'group-by' => [0],
            'sort-by' => [-1]
          }
        }
      end

      def apply_additional_arguments!(conf, args)
        return if args.nil?

        args_delimiter = /;\s*/

        options = args.split(args_delimiter).reduce({}) do |acc, e|
          k, v = e.split
          acc[k] = v
          acc
        end

        begin
          h, v = Integer(options['h'], 10), Integer(options['v'], 10)
          conf['layout'] = {
            'default' => {
              'custom' => {
                'max-horizontal' => h,
                'max-vertical' => v,
                'panes-flow' => 'horizontal'
              }
            }
          }
        rescue
        end
      end

      def generate_groups()
        @groups = hosts.reduce({}) do |acc, e|
          acc[e.group_id] ||= []
          acc[e.group_id] << e
          acc
        end

        if (hostless = config['hostless'])
          @groups.merge! Hash[hostless.map { |name, count| [ name, [FakeHost.new(name, count)] ] }]
        end

        update_sort_values!

        groups.each do |_, hosts|
          hosts.sort_by!(&:sort_value)
        end
      end

      def update_sort_values!()
        groups.each do |_, hosts|
          numbers_only = hosts.all? { |e| e.sort_value =~ /^[-+]?[0-9]+$/ }

          if numbers_only
            hosts.each { |h| h.sort_value = Integer(h.sort_value, 10) }
          end
        end
      end

      def generate_merge_rules()
        @merge_rules = {}
        if config['merge-groups']
          config['merge-groups'].each do |name, elements|
            elements.each { |e| @merge_rules[e] = name }
          end
        end
        groups.keys.each { |e| @merge_rules[e] ||= e }
      end
  end
end
