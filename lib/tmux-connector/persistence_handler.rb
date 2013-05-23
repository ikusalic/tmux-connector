require 'fileutils'


module TmuxConnector
  BASE_DIR = File.expand_path '~/.tmux-connector'
  MAIN_FILE = File.join BASE_DIR, '_sessions.yml'
  SESSION_BASE_NAME = "s#"

  def self.save_session(session_name, session_obj)
    prepare_if_necessary

    created = Time.now.strftime('%Y-%m-%d %H:%M')

    file = File.join(BASE_DIR, "#{ session_name.gsub(/[^a-zA-Z0-9_-]+/, '-') }.bin")
    file.sub!('.bin', "__#{ created.gsub(/[ :]/, '_') }.bin") if File.exists? file

    update_main_file(session_name, created, file, session_obj.args['--purpose'])

    open(file, 'wb') { |f| Marshal.dump session_obj, f }
  end

  def self.load_session(session_name)
    data = list_sessions
    raise "session not found: '#{ session_name }'" if data[session_name].nil?

    file = data[session_name]['file']
    raise "session file (#{ file }) not found" unless File.exist? file

    session = nil
    open(file, 'rb') { |f| session = Marshal.load f }
    return session
  end

  def self.prepare_if_necessary()
    unless File.exists?(BASE_DIR) && File.directory?(BASE_DIR)
      Dir.mkdir(BASE_DIR)
    end

    FileUtils.touch MAIN_FILE unless File.exists? MAIN_FILE
  end

  def self.delete_all()
    FileUtils.rm_rf BASE_DIR
  end

  def self.update_main_file(session_name, created, file, purpose)
    data = list_sessions

    data[session_name] = {
      'created' => created,
      'file' => file
    }
    data[session_name]['purpose'] = purpose if purpose

    open(MAIN_FILE, 'w') { |f| f.write data.to_yaml }

    return file
  end

  def self.delete_session(session_name)
    data = list_sessions
    raise "session not found: '#{ session_name }'" if data[session_name].nil?

    file = data[session_name]['file']
    data.delete session_name
    open(MAIN_FILE, 'w') { |f| f.write data.to_yaml }
    File.delete(file) rescue nil
  end

  def self.list_sessions(options={})
    unless options[:suppress_error]
      raise "session file (#{ MAIN_FILE }) not found" unless File.exist? MAIN_FILE
    end
    return ( YAML.load_file(MAIN_FILE) rescue {} ) || {}
  end

  def self.get_new_session_name(args)
    specified = args["--session-name"]

    if File.exists? MAIN_FILE
      existing_names = list_sessions.keys

      if specified
        raise "session with name '#{ specified }' already exists." if existing_names.include? specified
        name = specified
      else
        re = /#{ SESSION_BASE_NAME }(\d+)/

        last_index = existing_names.reduce(0) do |acc, e|
          index = ( e.match(re)[1].to_i rescue 0 )
          [ acc, index].max
        end

        name = "#{ SESSION_BASE_NAME }#{ last_index + 1 }"
      end
    else
      name = specified || "#{ SESSION_BASE_NAME }1"
    end

    return name
  end
end
