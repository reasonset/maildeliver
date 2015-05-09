#!/usr/bin/ruby
# -*- mode: ruby; coding: UTF-8 -*-
require 'yaml'


class StandardNotify
  PLUGINS = []
  ARG = {}
  def initialize
    
    ### Load configuration file.
    self.instance_eval(File.read(ENV["maildeliv_conf"] || "#{ENV["HOME"]}/.yek/maildeliv/maildelivrc.rb"))
    
    if @maildeliv_conf[:ModuleDir]
      $:.unshift @maildeliv_conf[:ModuleDir]
    end
    ############################
    
    
    #Prepare database
    readmemos()
    
    return if @headers.size < 1
    
    construct_db()

    
    #parsing options
    parse_arg(ARGV)
    
    ###DEBUG###
    #p @arg
    #p @headers
    #p @db
    ###########
    
    invoke_plugins()
  end
  
  
  def readmemos
    memodir = (ENV["maildeliv_tempdir"] ||@maildeliv_conf[:TempDir] || "#{ENV["HOME"]}/tmp/recv-mails")
    @headers = Array.new

    # Get jotted header files.
    Dir.glob("#{memodir}/*.yaml").each do |i|
      m = YAML.load(File.open(i)) rescue next
      File.unlink(i)
      @headers.push m
    end
  end
  
  def construct_db
    @db = {from: Hash.new(0), address: Hash.new(0), number: 0 }
    
    @headers.each do |h|
      @db[:address][h["__address"]] += 1 #Counting per address
      @db[:from][h["FROM"]] += 1 #Counting per from term.
    end
    
    @db[:number] = @headers.size #Total mail number
  end
  
  def parse_arg(arg)
    @arg = Hash.new(false)
    
    arg.each do |a|
      if a.include?("=")
        k, v = a.split("=", 2)
        @arg[k] = v
      else
        @arg[a] = true
      end
    end
    
    ARG.replace(@arg)
    
  end
  
  def invoke_plugins()
    Dir.glob((ENV["maildeliv_notify_plugdir"] || @maildeliv_conf[:NotifyPluginDir] || "#{ENV["HOME"]}/.yek/notify-plugins") + "/*.rb") do |i|
      load i
    end
    
    PLUGINS.each do |i|
      i.fire(@headers, @db)
    end
  end
  
end


StandardNotify.new