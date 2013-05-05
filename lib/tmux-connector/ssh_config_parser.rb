module SSHConfig
  HOST_REGEX = /^Host (.+)$/

  def self.get_hosts(config_file, reject_re=nil)
    hosts = read_config(config_file).scan(HOST_REGEX).map(&:first).map(&:strip)
    hosts.reject! { |e| e.match reject_re } if reject_re
    return hosts
  end

  def self.read_config(config_file)
    full_path = File.expand_path config_file
    raise "ssh config file (#{config_file}) not found" unless File.exist? full_path
    return open(full_path).read
  end
end
