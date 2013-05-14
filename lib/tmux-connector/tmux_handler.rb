module TmuxConnector
  def self.delete_tmux_session(name)
    system "tmux kill-session -t #{ name } &> /dev/null"
  end

  def self.delete_all_tmux_sessions()
    sessions_list = %x( tmux list-sessions &> /dev/null )
    sessions = sessions_list.scan(/^([^:]+): /).map(&:first)
    sessions.each { |e| delete_tmux_session e }
  end


  class TmuxSession
    attr_reader :name
    attr_reader :session
    attr_accessor :commands

    def initialize(session)
      @session = session

      @name = session.name
      @commands = []
    end

    def start_session()
      create_session
      create_windows
      create_panes
      clear_panes

      connect

      attach_to_session

      execute
    end

    def send_commands(send_commands, server_regex, group_regex)
      count = 0
      each_pane do |window_index, pane_index, host|
        if( (server_regex.nil? || host.ssh_name.match(server_regex)) &&
            (group_regex.nil? || host.group_id.match(group_regex) ||
              session.merge_rules[host.group_id].match(group_regex)) )
          system("tmux send-keys -t #{ name }:#{ window_index }.#{ pane_index } '#{ send_commands }' C-m")
          count += 1
        end
      end

      puts "command sent to #{ count } server[s]"
    end

  private

      def execute()
        commands.each { |e| system e }
      end

      def create_session()
        commands << <<HERE
tmux start-server

tmux has-session -t #{ name } &> /dev/null
[ $? -eq 0 ] && tmux kill-session -t #{ name }

tmux new-session -s #{ name } -n RENAME -d
HERE
      end

      def create_windows()
        session.windows.each_with_index do |w, i|
          if i == 0
            commands << "tmux rename-window -t #{ name }:0 #{ w[:name] }"
          else
            commands << "tmux new-window -t #{ name }:#{ i } -n #{ w[:name] }"
          end
        end
      end

      def create_panes()
        session.windows.each_with_index do |w, wi|
          commands << "tmux select-window -t #{ name }:0"
          if w[:tmux]
            w[:panes].each_with_index do |p, pi|
              # size is specified so panes are not to small and cause errors
              size = (100.0 * (w[:panes].size - pi - 1) / (w[:panes].size - pi)).round

              commands << "tmux split-window -p #{ size } -t #{ name }:#{ wi }" unless pi == 0
              commands << tmux_set_title_cmd(p.display_name, wi, pi)
            end

            commands << "tmux select-layout -t #{ name }:#{ wi } #{ w[:tmux] } &> /dev/null"
          else
            create_custom_layout w, wi
          end

          commands << "tmux select-pane -t #{ name }:#{ wi }.0"
        end
      end

      def clear_panes()
        each_pane do |window_index, pane_index|
          commands << "tmux send-keys -t #{ name }:#{ window_index }.#{ pane_index } clear C-m"
        end
      end

      def connect()
        ssh_config_path = File.expand_path session.args['--ssh-config']

        each_pane do |window_index, pane_index, host|
          ssh_command = "ssh -F #{ ssh_config_path } #{ host.ssh_name }"
          commands << "tmux send-keys -t #{ name }:#{ window_index }.#{ pane_index } '#{ ssh_command }' C-m"
        end
      end

      def attach_to_session()
        commands << <<HERE
tmux select-pane -t #{ name }:0.0
tmux select-window -t #{ name }:0
tmux attach -t #{ name }
HERE
      end

      def each_pane(&block)
        session.windows.each_with_index do |window, window_index|
          if window[:tmux]
            window[:panes].each_with_index do |host, pane_index|
              yield(window_index, pane_index, host)
            end
          else
            pane_index = 0
            window[:panes].each do |g|
              g.each do |host|
                yield(window_index, pane_index, host)
                pane_index += 1
              end
            end
          end
        end
      end

      def create_custom_layout(window, window_index)
        direction = (window[:flow] == 'horizontal') ? ['-h', '-v'] : ['-v', '-h']

        pane_index = 0
        window[:panes].each_with_index do |group, group_index|
          commands << "tmux select-pane -t #{ name }:#{ window_index }.#{ pane_index }"

          # create pane in a next row ahead of time so pane indexes match hosts
          if group_index < window[:panes].size - 1
            size = (100.0 * (window[:panes].size - group_index - 1) / (window[:panes].size - group_index)).round
            commands << "tmux split-window #{ direction[1] } -p #{ size } -t #{ name }:#{ window_index }"
            display_name = window[:panes][group_index + 1][0].display_name
            commands << tmux_set_title_cmd(display_name, window_index, -1)
            commands << "tmux select-pane -t #{ name }:#{ window_index }.#{ pane_index }"
          end

          group.each_with_index do |host, host_index|
            size = (100.0 * (group.size - host_index) / (group.size - host_index + 1)).round
            commands << "tmux split-window #{ direction[0] } -p #{ size } -t #{ name }:#{ window_index }" unless host_index == 0
            commands << tmux_set_title_cmd(host.display_name, window_index, pane_index)

            pane_index += 1
          end
        end
      end

      def tmux_set_title_cmd(title, window_id, pane_id)  # pane_id == -1 -> do not specify
        keys = %q|printf '\033]2;%s\033\\'| + " '#{ title }'"
        pane_id_str = (pane_id == -1) ? '' : ".#{ pane_id }"
        return %Q|tmux send-keys -t #{ name }:#{ window_id }#{ pane_id_str } "#{ keys }" C-m|
      end
  end
end
