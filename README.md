# TmuxConnector

Manage multiple servers using SSH and [tmux].


## Features:
* work on multiple sessions in parallel
* sessions can be persisted (actually recreated) after computer restarts
    - they are lost only if you delete them explicitly
* complex layouts customizable for different server groups
* issuing commands to all servers or just a selected subgroups

## Quick tease

`tcon start staging_config.yml -n staging -p 'all staging servers'`

- crate a session (name: 'staging', description: 'all staging servers') with
complex layout structure (multiple windows with (potentially) different pane
layouts)
- connect to all servers
- attach to tmux session

`tcon send staging 'sudo su'`

- send to all servers (in 'staging' session) `sudo su` command

`tcon send staging 'top' -g 'lbs'`

- send `top` command to all loadbalancing nodes in 'staging' session

`tcon send production 'tail -f' -f 'rdb'`

- send `tail -f` command to all database nodes in 'production' session


## CLI description

[CLI] uses [docopt] to parse command line options.

~~~
tcon enables establishing connections (ssh) to multiple servers and executing
commands on those servers. The sessions can be persisted (actually recreated)
even after computer restarts. Complex sessions with different layouts for
different kinds of servers can be easily created.

Usage:
  tcon start <config-file> [--ssh-config=<file>]
             [--session-name=<name>] [--purpose=<description>]
  tcon resume <session-name>
  tcon delete <session-name>
  tcon list
  tcon send <session-name> (<command> | --command-file=<file>)
            [--server-filter=<regex>] [--group-filter=<regex>]
  tcon --help
  tcon --version

Options:
  <config-file>              Path to configuration file. Configuration file
                             describes how new session is started. YAML format.
  <session-name>             Name that identifies the session. Must be unique.
  <command>                  Command to be executed on remote server[s].
  -s --ssh-config=file       Path to ssh config file [default: ~/.ssh/config].
  -n --session-name=name     Name of the session to be used in the tcon command.
  -p --purpose=description   Description of session's purpose.
  -f --server-filter=regex   Filter to select a subset of the servers.
                             Should be valid ruby regex.
  -g --group-filter=regex    Filter to select a subset of the servers via
                             group membership.  Should be valid ruby regex.
  -c --command-file=file     File containing the list of commands to be
                             executed on remote server[s].
  -h --help                  Show this screen.
  --version                  Show version.
~~~


## Configuration

To use this gem, you need to create a configuration file. This shouldn't be
that hard and here I provide exhaustive details about configuration files.

(If there is enough interest, in future versions there could be a special
command to simplify generation of configuration files. To accelerate the
process, open an issue or drop me an email: << username >>@gmail.com)

Let's get to it.

The configuration file is in [YAML] format.

Let's say the following ssh config file that will be used:
~~~
KeepAlive yes
ServerAliveInterval 2
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null

Host staging.cache-staging-1
  Hostname ec2-111-42-111-42.eu-west-1.compute.amazonaws.com
  Port 4242
  IdentityFile /Users/ikusalic/.ssh/some-pem-file.pem
  User ubuntu

Host dev.database-staging-1
  << omitted >>

Host dev.database-staging-3
  << omitted >>

Host dev.mongodb-single-replica-1
  << omitted >>

Host dev.haproxy-staging-72
  << omitted >>

Host dev.haproxy-staging-73
  << omitted >>

Host dev.nginx-staging-11
  << omitted >>

Host dev.nginx-staging-15
  << omitted >>

Host dev.node-staging-127
  << omitted >>

Host dev.node-staging-129
  << omitted >>

Host dev.node-staging-130
  << omitted >>

Host dev.node-staging-135
  << omitted >>

<< ... >>
~~~

Here's a 'real world' configuration file that shows of all the available
options and could be use with previous ssh config file:

~~~yaml
regex: !ruby-regexp '^(\w+).(\w+)-([\w-]+)-(\d+)$'
reject-regex: !ruby-regexp '-(nodes|to_ignore)-'
regex-parts-to:
    group-by: [1]
    sort-by: [3]
name:
    regex-ignore-parts: [0, 2]
    separator: '-'
    prefix: 'dev--'
merge-groups:
    misc: ['cache', 'db', 'mongodb']
    lbs: ['haproxy', 'nginx']
layout:
    default:
        custom:
            max-horizontal: 3
            max-vertical: 3
            panes-flow: vertical
    group-layouts:
         misc:
            tmux:
                layout: 'tiled'
                max-panes: 6
         node:
            tmux:
                layout: 'tiled'
~~~

* * *
__'regex'__ field is the most important field. Manny other field reference to this
one. This field provides a rule on how to parse host names from ssh config file.
The regex should be a valid ruby regex. (If you're not familiar with ruby
regexes, consider visiting [rubulator] and playing around.)

For example if ssh config file include the following host definition:
~~~
Host dev.database-staging-1
~~~

and the following regex is used:
~~~
regex: !ruby-regexp '^(\w+).(\w+)-([\w-]+)-(\d+)$'
~~~

the name 'dev.database-staging-1' will be broken to 4 groups:
~~~
'dev', 'database', 'staging', 1
~~~

This regex is used for all the host names and should be designed accordingly.

The idea behind the regex is to enable sorting and grouping of hosts from regex
groups extracted from host names. Those groups are used to crate meaningful
layouts. I know, sounds more complex than it really is...

* * *
__'reject-regex'__ (optional) field is used to ignore some hosts while starting a
session.

* * *
Fields (__'regex-parts-to'__) __'group-by'__ and __'sort-by'__ are referencing before
mentioned __'regex'__ field. As their names suggest, they decide which servers
constitute a group (and share layout and potentially commands) and how to sort
serves in a group. Both fields can reference more than one regex group.

In the above example, for 'dev.database-staging-1' host name, a group to which
the host belongs would be 2nd group, which is: 'database'.

* * *
(optional) field __'name'__ and it's (optional) subfields __'regex-ignore-parts'__,
__'separator'__ and __'prefix'__ decide how to name the servers. If those fields are
omitted, ssh host name is used instead

Filed __'regex-ignore-parts'__ potentially removes some regex groups from name,
__'separator'__ is used to separate left-over groups and it's possible to specify
__'prefix'__ for the name.

* * *
(optional) field __'merge-groups'__ contains groups that should be merged (for
layout purposes) together. This can be used to group a few servers that are
unique in type or small in numbers. E.g. grouping different DB servers.

~~~
    lbs: ['haproxy', 'nginx']
~~~
In this example two different kinds of loadbalancers are grouped together.

Note that the servers from merge groups can later be referenced with both
original and merge-group name.

* * *
Finally, what's left is the layout definition:

There are 2 main ways to specify a layout for a (merge-)group:

1. built-in tmux layouts (even-horizontal, even-vertical, main-horizontal,
main-vertical or tiled)
    - defines a tmux layout and (optionally) maximum number of panes in one
window (default 9).
2. custom tiled layout
    -  defines filed layout with maximal size of rows and columns. There is also
an (optional) option to specify if the panes flow from left to right
(horizontal - default) or from top to bottom (vertical)

The layouts are applied individually to any merge group and to any normal
(regex) group not belonging to some merge group. If there are more servers in
a group then layout allows on a single window, next window for that group is
added. Servers from different groups never share a window.


## Installation

The gem provides CLI and currently it is not intended to be used as part of
bigger ruby apps.

Install it with:
~~~
$ gem install tmux-connector
~~~


## Requirements
To be able to use the gem you should have ruby 1.9+ and tmux installed on a *nix machine
(Windows: here be dragons).

Interaction with tmux is done via bash commands.

Minimal familiarity with tmux is required.
For start switching between panes/windows and attaching/detaching is enough.


## Tips

###  SSH config files

If you plan on specifying separate ssh config file when starting session,
consider adding the following lines on top:
~~~
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null
~~~

That way you won't have problems with known hosts changes or with infinite
questions to approve new hosts. Do this _only_ if you understand security
consequences and are sure that it is safe to do so.


### Tmux configuration

Since gem uses tmux, consider configuring it for your purposes. E.g. I'm a [Vim]
user, and so configure tmux to use Vim-like bindings to switch panes. For more
information, check my [dotfiles].


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

Or just mail me, mail: << username >>@gmail.com

This is my first real gem, so all your comments are more than welcome.
I'd really appreciate ruby code improvements/refactoring comments or usability
comments (all other are welcome too). Just _drop me a line_. :)


## Comments, ideas or if you feel like chatting

Take a look at `TODO.md` file (in the repository) for ideas about additional
features in new versions.

<< username >>@gmail.com

I'd be happy to hear from you.


[docopt]: https://github.com/docopt/docopt
[tmux]: http://en.wikipedia.org/wiki/Tmux
[CLI]: http://en.wikipedia.org/wiki/Command-line_interface
[Vim]: http://www.vim.org/
[dotfiles]: https://github.com/ikusalic/dotfiles
[YAML]: http://en.wikipedia.org/wiki/YAML
[rubulator]: http://rubular.com/
