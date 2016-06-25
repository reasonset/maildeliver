#!/usr/bin/ruby
# -*- mode: ruby; coding: UTF-8 -*-
require 'yaml'

class SaveMailHeader
  ARGS = StandardNotify::ARG
  
  def initialize
    self.instance_eval(File.read(ENV["maildeliv_conf"] || "#{ENV["HOME"]}/.yek/maildeliv/maildelivrc.rb")) # To use configuration file.
    @memofile = (ENV["maildeliv_tempdir"] || @maildeliv_conf[:TempDir] || "#{ENV["HOME"]}/tmp/recv-mails") + ".summery"
  end
  
  def fire(headers, db)
    unless File.exist? @memofile
      File.open(@memofile, "w") {|f| nil }
    end
    
    File.open(@memofile, "r+") do |f|
      f.flock(File::LOCK_EX)
      db = (YAML.load(f) rescue nil)
      db ||= []
      
      db.concat headers
      f.seek(0)
      f.truncate(0)
      YAML.dump(db ,f)
    end
  end
end

StandardNotify::PLUGINS.unshift SaveMailHeader.new
