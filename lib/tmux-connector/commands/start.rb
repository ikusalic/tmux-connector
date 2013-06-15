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
      @config = TmuxConnector.get_config args['<config-file>']

      ssh_hostnames = SSHConfig.get_hosts(args['--ssh-config'], config['reject-regex'])
      @hosts = ssh_hostnames.reduce([]) do |acc, name|
        ( acc << Host.new(name, config) ) rescue nil
        acc
      end
      raise "no hosts matching given configuration found, check your configuration file" if hosts.empty?


      generate_groups
      generate_merge_rules

      @session = Session.new config, args, groups, merge_rules
    end

    def run()
      session.save
      session.start
    end

  private

      def generate_groups()
        @groups = hosts.reduce({}) do |acc, e|
          acc[e.group_id] ||= []
          acc[e.group_id] << e
          acc
        end

        if (hostless = config['hostless'])
          @groups.merge! Hash[hostless.map { |name, count| [ name, [FakeHost.new(name, count)] ] }]
        end

        sort_groups!
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

      def sort_groups!()
        groups.each do |k, v|
          numbers_only = v.all? { |e| e.sort_value =~ /^[-+]?[0-9]+$/ }
          if numbers_only
            v.sort! { |a, b| a.sort_value.to_i <=> b.sort_value.to_i }
          else
            v.sort_by!(&:sort_value)
          end
        end
      end
  end
end
