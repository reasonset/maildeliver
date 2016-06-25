#!/usr/bin/ruby
# -*- mode: ruby; coding: UTF-8 -*-
require 'yaml'

class YadSystray
  def initialize
    self.instance_eval(File.read(ENV["maildeliv_conf"] || "#{ENV["HOME"]}/.yek/maildeliv/maildelivrc.rb")) # To use configuration file.
    @memofile = (ENV["maildeliv_tempdir"] || @maildeliv_conf[:TempDir] || "#{ENV["HOME"]}/tmp/recv-mails") + ".summery"
    @zenitylist = (ENV["maildeliv_tempdir"] || @maildeliv_conf[:TempDir] || "#{ENV["HOME"]}/tmp/recv-mails") + ".yad"
  end
  
  def fire(headers, db)
    mails = (YAML.load(File.open(@memofile)) || []).map {|i| [(i["FROM"] || ""), (i["DATE"] || ""), (i["SUBJECT"] || "") ] }
    File.open(@zenitylist, "w+") do |f| 
      f.flock(File::LOCK_EX)
      f.seek(0)
      f.truncate(0)
      f.print mails.join("\n")
    end
  end
end

StandardNotify::PLUGINS << YadSystray.new
