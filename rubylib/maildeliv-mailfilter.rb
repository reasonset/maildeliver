#!/usr/bin/ruby
# -*- mode: ruby; coding: UTF-8 -*-
require 'fileutils'

module MailFilter
  def savemail(path, exit_after_saving)
    
    #DEBUG#
    #STDERR.puts "##Savemail##"
    #######
    
    dir = "#{@maildeliv_conf[:MH]}/#{path}"
    
    ###DEBUG###
    #p @maildeliv_conf[:MH]
    #p path
    ###########
    
    if not File.exist?(dir)
      FileUtils.mkdir_p(dir)
    end
    
    #Get max index.
    maxi = Dir.foreach(dir).max_by {|i| i =~ /^[0-9]+$/ ? i.to_i : -1 }
    maxi = maxi =~ /^[0-9]+$/ ? maxi.to_i : 0
    
    index = maxi.to_i.succ
    
    ###DEBUG###
    #p maxi
    #p index
    ###########
    
    File.open("#{dir}/#{index}", "w") do |f|
      f.write @mailobj.mailstr
    end
    
    
    ###DEBUG###
    #p dir
    #p index
    ###########
    
    STDERR.puts "savemail(): Write to #{dir}/#{index}"
    
    if exit_after_saving
      throw :filtering
    end
    
  end
  
  def destroymail
    STDERR.puts "destroymail() : Destroy a mail from #{@mailobj.address}"
    if [[ File.exist?(@memofile) ]]
      File.unlink @memofile
    end
    throw :filtering
  end
  
end

MailDeliver::Filter = Struct.new(:condition, :proc)