#check-barman

A nagios plugin for PostgreSQL backup tool [barman](http://www.pgbarman.org)


## Overview

This plugin is able to do several checks:

* SSH connection to Master server
* PostgreSQL connection to Master server
* Available Backups
* Time of last received WAL file
* Failed backups
* Missing WAL files in the latest backup


## Installation

This plugin is written in Ruby, so a working Ruby installation is required

```sh
$ git clone https://github.com/hamann/check-barman
$ cd check-barman
$ gem install rbarman
$ chmod +x check-barman.rb
$ ./check-barman.rb
Usage check-barman.rb [options]
    -a, --action ACTION              The name of the check to be executed
    -s, --server SERVER              The 'server' in barman terms
    -w, --warning WARNING            The warning level
    -c, --critical CRITICAL          The critical level
    -h, --barman-home PATH           path to barman's Home directory, default /var/lib/barman
    -b, --barman-binary PATH         path to barman binary, default /usr/bin/barman
```

## Usage

To test this script, become 'barman' user

The parameters `action` (-a/--action) and `server` (-s /--server) are required, where `action` can be one of

* ssh
* pg
* backups_available
* last_wal_received
* failed_backups
* missing_wals

The parameters `warning` and `critical` are required if `action` is `backups_available`, `last_wal_received` or `failed_backups` and its values depend on the action context:

* backups_available => number
* last_wal_received => seconds
* failed_backups => number

Examples:

check if SSH connection to master server is ok

```sh
$ ./check-barman.rb -a ssh -s test1
SSH connection ok
```

check if PostgreSQL connection to the master server is ok
```sh
$ ./check-barman.rb -a pg -s test1
PG connection ok
```

check number of backups and set warning if number of backups is > 5 or set critical if number of backups is > 6 
```sh
$ ./check-barman.rb -a backups_available -s test1 -w 5 -c 6
"4 backups available"
```

check when the last WAL file was received and set warning if time difference is > 300 seconds or set critical if time difference is > 600 seconds
```sh
$ ./check-barman.rb -a last_wal_received -s test1 -w 300 -c 600
"Last wal was received 121 seconds ago (000000010000109100000014)"
```

check if there are failed backups
```sh
$ ./check-barman.rb -a failed_backups -s test1 -w 1 -c 2
```

check if all WAL files exist in the latest backup. This check is more time consuming because it has to compute the range of WAL files which have to exist since start of base backup and the last received WAL file, and check for there according entry in xlog.db (=> barman processed them). Consider to increase check_timeout or check_interval in case your backups are large!
```sh
$ ./check-barman.rb -a missing_wals -s test1
"There are no missing wal files in the latest backup"
```

## Configuration

Give `nagios` user all privileges to read backup data or executing `barman` by adding an entry to `sudoers` file like:
```
Defaults:nagios !requiretty
nagios ALL=NOPASSWD:/usr/lib/nagios/plugins/check-barman/check-barman.rb
```

and use '-h /var/lib/barman' as option to nagios or nrpe command definition, e.g for `nrpe`

```
$ cat /etc/nagios/nrpe.d/barman_commands.cfg
command[check_barman_missing_wals_test]=sudo /usr/lib/nagios/plugins/check-barman/check-barman.rb -a missing_wals -h /var/lib/barman -s test
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


## License and Authors

* Author:: Holger Amann holger@sauspiel.de

* Copyright:: 2013, holger@sauspiel.de

Licensed under the [MIT License](http://opensource.org/licenses/mit-license.php)





