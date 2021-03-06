# TmuxConnector

Manage multiple servers using SSH and [tmux].

For the demo and short intro, read [this blog post][blog-post].


- [Features](#features)
- [Quick tease](#quick-tease)
- [CLI description](#cli-description)
    - [Send command](#send-command)
- [Configuration](#configuration)
- [Sessions without configuration files](#sessions-without-configuration-files)
- [Requirements](#requirements)
- [Installation](#installation)
    - [Installing tmux](#installing-tmux)
- [Tips](#tips)
    - [SSH config files](#ssh-config-files)
    - [Tmux configuration](#tmux-configuration)
    - [Sending the commands](#sending-the-commands)
- [Contributing](#contributing)
- [Comments, ideas or if you feel like chatting](#comments-ideas-or-if-you-feel-like-chatting)


## Features

* connect to multiple servers at once
* expressive layouts customizable for different server groups available
* issue commands to all servers or just a selected (custom) subgroup
* work on multiple sessions in parallel
* multiple connections to individual servers possible
* sessions can be persisted (actually recreated) after computer restarts
    - they are lost only if you delete them explicitly
* panes not associated with hosts available


## Quick tease

`tcon start staging_config.yml -n staging -p 'all staging servers'`

- crate a session (name: 'staging', description: 'all staging servers') with
    complex layout structure (multiple windows with (potentially) different pane
    layouts)
- connect to all servers
- attach to tmux session

`tcon send staging 'sudo su'`

- send to all servers (in 'staging' session) `sudo su` command

`tcon send staging -v -g 'lbs' 'top'`

- send `top` command to all loadbalancing nodes in 'staging' session and report
  the number of affected nodes

`tcon send production -f 'worker' 'tail -f /var/log/syslog'`

- send `tail -f /var/log/syslog` command to all worker nodes in 'production'
    session

`tcon send production -f 'worker :: <,3]; 7; <9,13>' 'C-c'`

- send `Ctrl-C` to some worker nodes in 'production' session, if executed
    after the `tail -f /var/log/syslog` command, it will exit the `tail -f`
    command
    - if there are worker nodes numbered from 1 to 20 (e.g. staging-worker-1,
      staging-worker-2, etc.) this command affects worker nodes: 1, 2, 3, 7, 10,
      11 and 12

`tcon resume s#3`

- resume (recreate) 's#3' session, even after computer restart

`tcon start -q "dev.node-staging-[[42,]]"`

- starts quick session (no config file); selects all 'node' servers that have
  index of at least 42


## CLI description

[CLI] uses [docopt] to parse command line options.

~~~
tcon enables establishing connections (ssh) to multiple servers and executing
commands on those servers. The sessions can be persisted (actually recreated)
even after computer restarts. Complex sessions with different layouts for
different kinds of servers can be easily created.

Usage:
  tcon start ( <config-file> | --quick-session=<qs-args> )
             [--ssh-config=<file>] [--session-name=<name>]
             [--purpose=<description>]
  tcon resume <session-name>
  tcon delete (<session-name> | --all)
  tcon list
  tcon send <session-name> ( <command> | --command-file=<file> )
            [ --server-filter=<filter> | --group-filter=<regex>
              | --filter=<regex> | --window=<index> ]
            [--verbose]
  tcon --help
  tcon --version

Options:
  <config-file>                Path to configuration file. Configuration file
                               describes how new session is started. YAML.
  <qs-args>                    Arguments needed to start a quick session.
  <session-name>               Name to identify the session. Must be unique.
  <command>                    Command to be executed on remote server[s].
  <regex>                      String that represents valid Ruby regex.
  <index>                      0-based index.
  <filter>                     Filter consisting of a valid ruby regex and
                               optionally of a special predicate.
                               For more information see README file.
  -q --quick-session=qs-args   Start the seesion without a configuration file.
                               Specify necessary argumenst instead.
  -s --ssh-config=file         Path to ssh config file. [default: ~/.ssh/config]
  -n --session-name=name       Name of the session.
  -p --purpose=description     Description of session's purpose.
  --all                        Delete all existing sessions.
  -f --server-filter=filter    Filter to select a subset of the servers via
                               host names.
  -g --group-filter=regex      Filter to select a subset of the servers via
                               group membership.
  -r --filter=regex            Filter to select a subset of the servers via
                               host names or group membership.
                               Combines --server-filter and --group-filter.
  -w --window=index            Select a window via (0-based) index.
  -c --command-file=file       File containing the list of commands to be
                               executed on remote server[s].
  -v --verbose                 Report how many servers were affected by the
                               send command.
  -h --help                    Show this screen.
  --version                    Show version.
~~~


### Send command

Send command sends user specified command(s) to chosen panes.

Once more, here's the command syntax:
~~~
tcon send <session-name> (<command> | --command-file=<file>)
          [ --server-filter=<filter> | --group-filter=<regex>
            | --filter=<regex> | --window=<index> ]
          [--verbose]
~~~
where long flags can be shortened to: `-c`, `-f`, `-g`, `-r`, `-w` and `-v`.

There are 4 flags used to filter the servers (panes) that are going to receive
the command(s):

* `-f` filters the servers via host names
    - accept valid ruby regex and optionally intervals specification
        - syntax: `<ruby-regex>` or `<ruby-regex> :: <intervals-specification>`
* `-g` filters the servers via group names
    - accepts valid ruby regex
* `-r` filters the servers via host names or group names
    - accepts valid ruby regex
* `-w` filters the servers that belong to particular layout window
    - accepts 0-based index

The `-f` filter can accept optional interval specification:
* interval specification operates on __'sort-by'__ part of host names (defined in
  configuration file)
    - intervals specification consists of one or more elements separated
    by semicollon (the split regex is: `/;\s*/`)
    - individual element is either an interval description or white-listed element
    - interval description consists of 4 parts:
        + '[' or '<' - include or exclude the first element
        + first element (can be empty)
        + ',' (can have trailing whitespace)
        + second element (can be empty)
        + ']' or '>' - include or exclude the last element
        - regex used:
          `/(?<start>[\[<])(?<first>[^,]*),\s*(?<second>[^\]>]*)(?<end>[\]>])/`
    - examples:
        + `2; 4` - 2, 4
        + `[1,3]` - 1, 2, 3
        + `[1, 3>` - 1, 2
        + `<1, 3>` - 2
        + `<,5>`  - ... 3, 4
        + `[5, >`  - 5, 6, ...

Hopefully now the following examples make more sense:

~~~bash
tcon send staging 'sudo su'
tcon send staging -v -g 'lbs' 'top'
tcon send production -f 'worker' 'tail -f /var/log/syslog'
tcon send production -f 'worker :: <,3]; 7; <9,13>' 'C-c'
~~~


## Configuration

To use this gem, you usually need to create a configuration file.

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
  IdentityFile /Users/some-user/.ssh/some-pem-file.pem
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

<< ... >>
~~~

Every configuration file needs to define at least the folowing fields:
__'regex'__, __'regex-parts-to'__, __'group-by'__ and __'sort-by'__

Here's a minimal configuration file that could be used:
~~~yaml
regex: !ruby-regexp '^(\w+)\.(\w+)-([\w-]+)-(\d+)$'
regex-parts-to:
    group-by: [1]
    sort-by: [3]
~~~

And here's a 'real world' configuration file that shows off all the available
options and could be use with previous ssh config file:

~~~yaml
regex: !ruby-regexp '^(\w+)\.(\w+)-([\w-]+)-(\d+)$'
reject-regex: !ruby-regexp '-(nodes|to_ignore)-'
regex-parts-to:
    group-by: [1]
    sort-by: [3]
name:
    regex-ignore-parts: [0, 2]
    separator: '-'
    prefix: 'dev--'
hostless:
    ctrl: 1
    additional: 2
merge-groups:
    misc: ['cache', 'db', 'mongodb']
    lbs: ['haproxy', 'nginx']
group-ranges:
    cache: [1, 4]
    node: [125, 131]
multiple-hosts:
    regexes:
        - !ruby-regexp '(nginx|haproxy)-'
        - !ruby-regexp '(db)-'
    counts: [2, 3]
layout:
    default:
        custom:
            max-horizontal: 3
            max-vertical: 3
            panes-flow: vertical
    group-layouts:
         misc:
            tmux:
                layout: tiled
                max-panes: 6
         node:
            tmux:
                layout: tiled
~~~

* * *
(required) __'regex'__ field is the most important field. Some other field
reference this one. It provides a rule on how to parse host names from ssh
config file.  The regex should be a valid ruby regex. (If you're not familiar
with ruby regexes, consider visiting [rubulator] and playing around.)

All host whose host names fail the regex will be ignored.

For example if ssh config file include the following host definition:
~~~
Host dev.database-staging-1
~~~

and the following regex is used:
~~~yaml
regex: !ruby-regexp '^(\w+)\.(\w+)-([\w-]+)-(\d+)$'
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
In (required) __'regex-parts-to'__ section, fields __'group-by'__ and
__'sort-by'__  are referencing before mentioned __'regex'__ field. As their
names suggest, they decide which servers constitute a group (and share layout
and potentially commands) and how to sort serves in a group. Both fields can
reference more than one regex group.

In the above example, for 'dev.database-staging-1' host name, a group to which
the host belongs would be 2nd group, which is: 'database'.

* * *
(optional) __'reject-regex'__ field is used to ignore some hosts while starting
a session.

* * *
(optional) field __'name'__ and it's (optional) subfields
__'regex-ignore-parts'__, __'separator'__ and __'prefix'__ decide how to name
the servers. If those fields are omitted, ssh host name is used instead.

Filed __'regex-ignore-parts'__ potentially removes some regex groups from name,
__'separator'__ is used to separate left-over groups and it's possible to
specify __'prefix'__ for the name.

* * *
(optional) field __'hostless'__ defines groups of panes that are not associated
with hosts. Each group is defined by the name and the number of panes.

For example,
~~~yaml
hostless:
    ctrl: 1
    additional: 2
~~~
defines 2 groups of panes without hosts. First group, 'ctrl', has only one
pane, while the second group, 'additional', has 2 panes.

Hostless panes can be used to:
* issue the tcon commands to other panes
    - e.g. one control pane, in a separate window
* manage local work
* connect to a host at some point in the future

* * *
(optional) field __'merge-groups'__ contains groups that should be merged (for
layout purposes) together. This can be used to group a few servers that are
unique in type or small in numbers. E.g. grouping different DB servers.

~~~yaml
lbs: ['haproxy', 'nginx']
~~~
In this example two different kinds of loadbalancers are grouped together.

Note that the servers/panes from merge groups can later be referenced with both
original and merge-group name.

Hostless groups can also be merged.

* * *
(optional) field __'group-ranges'__ contains groups that should be limited to
specific ranges of servers. Ranges are defined by lower and upper limits, both inclusive.
They are enforced on sort values (defined by aforementioned 'sort-by' field).

If the following group ranges were defined:
~~~yaml
group-ranges:
    cache: [1, 4]
    node: [125, 131]
~~~
Only cache servers with sort ids 1, 2, 3 or 4 would be included in the session.
Similarly for node servers, only servers with ids between 125 and 131 would be
included.

* * *
(optional) field __'multiple-hosts'__ contains __'regexes'__ and __'counts'__
fields. With those, some hosts can have multiple connections established, not
just the default one connection per host.

For example:
~~~yaml
multiple-hosts:
    regexes:
        - !ruby-regexp '(nginx|haproxy)-'
        - !ruby-regexp '(db)-'
    counts: [2, 3]
~~~
creates 2 connections for each of nginx or haproxy nodes, as well as 3
connection for db nodes.

Fields __'regexes'__ and __'counts'__ must have the same number of elements.
Each element in __'regexes'__ must contain valid ruby regex.

* * *
Finally, what's left is the (optional) __layout__ definition:

There are 2 main ways to specify a layout for a (merge-)group:

1. with option __tmux__, built-in tmux layouts: even-horizontal, even-vertical,
   main-horizontal, main-vertical or tiled
    - defines a tmux layout, option __'layout'__ and (optionally) maximum
      number of panes in one window, __'max-panes'__, default 9
2. with option __custom__, custom tiled layout
    -  defines filed layout with maximal size of rows, __'max-vertical'__, and
       columns, __'max-vertical'__. There is also an (optional) option
       __'panes-flow'__ to specify if the panes flow from left to right
       (horizontal - default) or from top to bottom (vertical)

If you don't specify layout, 'tmux tiled' will be used

The layouts are applied individually to any merge group and to any normal
(regex) group not belonging to some merge group. If there are more servers in
a group then layout allows on a single window, next window for that group is
added. Servers from different groups never share a window.

* * *
Take a look at [`spec/fixtures/configs.yml`][configs] for some configuration
possibilities (sections under 'input' fields).


## Sessions without configuration files

As mentioned in previous section, normally you need the configuration file to
start the session.

This is not true for some smaller sessions where you can directly specify all
necessary configuration in command line when starting the session.

You can use `--quick-session` (or `-q`) to start a quick session. Quick
session arguments must conform to the following format:
~~~
"<regex>[[<lower-limit>,<upper-limit>]]<additional-arguments>"
~~~
where:

* `<regex>` is similar to 'regex' filed in configuration file, but without the
  sorting part (which is presumably last part of the full regex)
* `<lower-limit>` and `<upper-limit>` are optional elements and define range of
  valid servers. Range is enforced on sorting part (which is not part of
  previous regex, but presumably comes after it)
* `<optional-additional-arguments>` is list of optional arguments. This list
  starts with ' :: ' and consists of key-value pairs separated by semicolon.
  Currently only `h` and `v` arguments are supported. Format:
  `:: h <max-horizontal-panes>; v <max-vertical-panes>`

Examples:

- `tcon start -q "dev.node-staging-[[1,24]]"`
- `tcon start -q "dev.node-staging-[[42,]]"`
- `tcon start -q "dev.node-staging-[[,]]"`
- `tcon start -q "dev.node-staging-[[,42]] :: h 2; v 2"`

Example with more complex regex (selects 2 kinds of servers):

- `tcon start -q "dev.(nginx|haproxy)-staging-[[10,30]] :: h 2; v 2"`


## Requirements
To be able to use the gem you should have ruby 1.9+ and tmux installed on a *nix
(Mac OS X, Linux, ...) machine. (Windows: here be dragons)

Interaction with tmux is done via bash commands.

Minimal familiarity with tmux is required.
For a start, switching between panes/windows and attaching/detaching is enough:

* detach session: `<prefix>d`
* attach session: `tmux attach -t <session-name>`
* navigate windows (next/previous): `<prefix>n` & `<prefix>p`
* navigate panes: `<prefix><arrow>`

Also useful:
* toggle pane zoom: `<prefix>z`

(prefix is by default `C-b`)


## Installation

The gem provides CLI and currently it is not intended to be used as part of
bigger ruby apps.

Install it with:
~~~
$ gem install tmux-connector
~~~


#### Installing tmux

If tmux isn't already installed, install it using your favorite mathod,
e.g.:
* Linux: `apt-get install tmux`
* Mac OS X: `brew install tmux`


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


### Sending the commands

You need to run the send command from somewhere. There are (at least) 2
options:

* have a controller pane (or the whole window) inside the tcon session
    - a pane not connected to a server to issue the commands to other panes
* have a separate terminal pane for issuing the send commands
    - I'm a iTerm2 user, and so I split the window vertically: much bigger
      top pane for the tcon session, and a smaller bottom pane to issue the
      send commands


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

Or just mail me, mail: ivan@<< username >>.com

This is my first real gem, so all your comments are more than welcome.
I'd really appreciate ruby code improvements/refactoring comments or usability
comments (all other are welcome too). Just _drop me a line_. :)


## Comments, ideas or if you feel like chatting

ivan@<< username >>.com

I'd be happy to hear from you.

Also, visit my [homepage].


[blog-post]: http://www.ikusalic.com/blog/2013/06/18/managing-multiple-servers-with-tcon/
[configs]: /spec/fixtures/configs.yml
[docopt]: https://github.com/docopt/docopt
[tmux]: http://en.wikipedia.org/wiki/Tmux
[CLI]: http://en.wikipedia.org/wiki/Command-line_interface
[Vim]: http://www.vim.org/
[dotfiles]: https://github.com/ikusalic/dotfiles
[YAML]: http://en.wikipedia.org/wiki/YAML
[rubulator]: http://rubular.com/
[homepage]: http://www.ikusalic.com/
