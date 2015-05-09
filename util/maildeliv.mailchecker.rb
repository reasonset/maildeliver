#!/usr/bin/ruby
# -*- mode: ruby; coding: UTF-8 -*-

# Run fetchmail and standard-notify.rb with ARGV[0] seconds interval.
# More arguments are pass through for standard-notify.rb.

INTERVAL = ARGV.shift.to_i

loop do
  system "fetchmail"
  
  system "maildeliv.standard-notify.rb", *ARGV
  
  sleep INTERVAL
end