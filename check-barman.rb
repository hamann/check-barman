#!/usr/bin/env ruby
# Copyright (c) 2013 Holger Amann <holger@sauspiel.de>
# 
# MIT License
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'optparse'
require 'rbarman'

include RBarman

def nagios_return_value(value, w, c)
  ret_val = 0
  if value >= c.to_i
    ret_val = 2
  elsif value >= w.to_i
    ret_val = 1
  else
    ret_val = 0
  end
  ret_val
end

def check_ssh(server)
  return_code = 0
  ssh_ok = Server.by_name(server).ssh_check_ok
  if ssh_ok
    puts "SSH connection ok"
  else
    puts "SSH connection failed!"
    return_code = 2
  end
  return_code
end

def check_pg(server)
  return_code = 0
  pg_ok = Server.by_name(server).pg_conn_ok
  if pg_ok
    puts "PG connection ok"
  else
    puts "PG connection failed!"
    return_code = 2
  end
  return_code
end

def check_backups_available(server, warning, critical)
  return_code = 0
  count = Backups.all(server).count
  if count == 0
    p "No backups available!"
  else
    p "#{count} backups available"
    nagios_return_value(count, warning, critical)
  end
end

def check_last_wal_received(server, warning, critical)
  last = Backups.all(server, { :with_wal_files => true }).latest.wal_files.last
  diff = (Time.now - (last.created - Time.now.gmt_offset)).to_i / 60
  p "Last wal was received #{diff} seconds ago (#{last})"
  nagios_return_value(diff, warning, critical)
end

def check_failed_backups(server, warning, critical)
  backups = Backups.all(server)
  count = 0
  backups.each do |backup|
    count = count + 1 if backup.status == :failed
  end
  p "#{count} backup(s) failed"
  nagios_return_value(count, warning, critical)
end

def check_missing_wals(server)
  missing = Backups.all(server, {:with_wal_files => true}).latest.missing_wal_files
  if missing.count == 0
    puts "There are no missing wal files in the latest backup"
    return 0
  else
    lines = Array.new
    missing.each { |m| lines << m.to_s }
    puts "There are #{missing.count} missing wal files in the latest backup:\n #{ lines.join("\n") }"
    return 2
  end
end

def validate_params(params)
  params.each do |k,v|
    if v.nil?
      raise OptionParser::MissingArgument.new("\'#{k.upcase}\' must be defined!")
    end
  end
end

options = {}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage check-barman.rb [options]"

  options[:action] = nil
  opts.on('-a', '--action ACTION',
          [
            :ssh,
            :pg,
            :backups_available,
            :last_wal_received,
            :failed_backups,
            :missing_wals
           ] ,'The name of the check to be executed') do |action|
    options[:action] = action
  end

  options[:server] = nil
  opts.on('-s', '--server SERVER ', String, 'The \'server\' in barman terms') do |server|
    options[:server] = server
  end

  options[:warning] = nil
  opts.on('-w', '--warning WARNING', 'The warning level') do |warn|
    options[:warning] = warn
  end

  options[:critical] = nil
  opts.on('-c', '--critical CRITICAL', 'The critical level') do |critical|
    options[:critical] = critical
  end

  options[:barman_home] = "/var/lib/barman"
  opts.on('-h', '--barman-home PATH', String, "path to barman's Home directory, default /var/lib/barman") do |h|
    options[:barman_home] = h
  end

  options[:barman_binary] = "/usr/bin/barman"
  opts.on('-b', '--barman-binary PATH', String, "path to barman binary, default /usr/bin/barman") do |b|
    options[:barman_binary] = b
  end

end

if ARGV.count == 0
  puts optparse
  exit 1
end

optparse.parse!

server = options[:server]
warning = options[:warning]
critical = options[:critical]
action = options[:action]

return_code = 1

Configuration.instance.binary = options[:barman_binary]
Configuration.instance.barman_home = options[:barman_home]

begin
  return_code = case action
                when :ssh
                  validate_params({:server => server})
                  check_ssh(server)
                when :pg
                  validate_params({:server => server})
                  check_pg(server)
                when :backups_available
                  validate_params({:server => server, :warning => warning, :critical => critical})
                  check_backups_available(server, warning, critical)
                when :last_wal_received
                  validate_params({:server => server, :warning => warning, :critical => critical})
                  check_last_wal_received(server, warning, critical)
                when :failed_backups
                  validate_params({:server => server, :warning => warning, :critical => critical})
                  check_failed_backups(server, warning, critical)
                when :missing_wals
                  validate_params({:server => server})
                  check_missing_wals(server)
                end
rescue OptionParser::MissingArgument
  puts $!.to_s
  puts optparse
  exit 1
end

exit return_code
