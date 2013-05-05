require_relative 'commands/delete'
require_relative 'commands/list'
require_relative 'commands/resume'
require_relative 'commands/send'
require_relative 'commands/start'


module TmuxConnector
  COMMANDS = %w[ start resume delete list send ]

  def self.process_command(args)
    command = detect_command args
    klass = get_class command
    command_obj = klass.new args
    command_obj.run
  end

  def self.detect_command(args)
    COMMANDS.each { |e| return e if args[e] }
    raise 'unkonwn command'
  end

  def self.get_class(command)
    class_name = command.split('-').map { |e| e.capitalize }.join
    return TmuxConnector.const_get class_name
  end
end
