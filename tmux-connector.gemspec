# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tmux-connector/version'

Gem::Specification.new do |gem|
  gem.name          = "tmux-connector"
  gem.version       = TmuxConnector::VERSION
  gem.authors       = ["Ivan Kusalic"]
  gem.email         = ["ikusalic@gmail.com"]  # TODO
  gem.summary       = %q{Manage multiple servers using SSH and tmux.}
  gem.description   = %q{tcon enables establishing connections (ssh) to multiple servers and executing commands on those servers. The sessions can be persisted (actually recreated) even after computer restarts. Complex sessions with different layouts for different kinds of servers can be easily created.} 
  gem.homepage      = "http://github.com/ikusalic"  # TODO

  gem.add_dependency('docopt')

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
