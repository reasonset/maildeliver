#!/usr/bin/ruby
# -*- mode: ruby; coding: UTF-8 -*-
require 'yaml'
require 'optparse'



class MailDeliver
  def initialize
    @clam = false
    @spam = false
    
    parse_opt
    main
  end

  def parse_opt
    op = OptionParser.new
    
    op.on("-c", "--clam") {|v| @clam = true }
    op.on("-a", "--assassin") {|v| @spam = true }
    op.on("-M", "--nomemo") {|v| @nomemo = true }
    
    op.parse(ARGV)
  end

  #Load configuration file.
  def loadconf()
    self.instance_eval(File.read(ENV["maildeliv_conf"] || "#{ENV["HOME"]}/.yek/maildeliv/maildelivrc.rb"))
    
    if @maildeliv_conf[:ModuleDir]
      $:.unshift @maildeliv_conf[:ModuleDir]
    end
    
    if ENV["maildeliv_rubylib"]
      $:.unshift ENV["maildeliv_rubylib"]
    end
    
    @maildeliv_conf[:MH] ||= "#{ENV["HOME"]}/Mail"
    

  end
  
  #Load modules
  def loadmods()
    require 'maildeliv-getheader'
    require 'maildeliv-mailfilter'
       
    self.extend GetHeader
    self.extend MailFilter
  end
    
  def loadfilter
    self.instance_eval(File.read(ENV["maildeliv_filter"] || "#{ENV["HOME"]}/.yek/maildeliv/filterrules.rb"))
    
  end
  
  
  #Read mail from STDIN.
  def readmail()
    STDIN.read
  end
  
  #Save header to memo file.
  def saveheader
    memodir = (ENV["maildeliv_tempdir"] ||@maildeliv_conf[:TempDir] || "#{ENV["HOME"]}/tmp/recv-mails")
    
    unless File.exist?(memodir)
      Dir.mkdir(memodir)
    end
    
    File.open(sprintf("%s/%.2f.yaml", memodir, Time.now.to_f), "w") do |f|
      YAML.dump(@mailobj.merge({"__address" => @mailobj.address }), f)
    end unless @nomemo
    
    nil
  end
  
  #Main
  def main    
    ##### LOADING #####
    
    loadconf
    loadmods
    loadfilter
    
    ###################
    
    
    ##### PARSING #####
    @mailstr = readmail
    
    @mailobj = getheader(@mailstr)
    
    getaddr(@mailobj)
    
    ###################
    
    
    if @maildeliv_conf[:BeforePlugins]
      @maildeliv_conf[:BeforePlugins].each {|plug| plug.(@mailobj) }
    end
    
    
    ##### SAVE HEADER #####
    saveheader
    #######################
    
    
    ##### FILTERING #####
    filter
    #####################
    
    if @maildeliv_conf[:AfterPlugins]
      @maildeliv_conf[:AfterPlugins].each {|plug| plug.(@mailobj) }
    end
    
  end
  
  #Filtering flow.
  def filter
    
    catch :filtering do
      ##### EXIT WITH throw :filtering #####
      
      clamcheck
      
      userfilter
      
      spamcheck
      
      defaultsaving
      
      ######################################
    end
    
  end
  
  #Clam Check
  def clamcheck
    if @clam && ( @mailobj.head.downcase.include?("multipart") || @mailobj.head.downcase.include?("boundary") )
      IO.popen("clamav", "-", "--quiet") do |io|
        io.write @mailstr
      end
      
      if $? != 0
        # ClamAV reports including a virus.
        savemail(@maildeliv_conf[:VirusIsolation], true)
      end
        
    end
  end
  
  #Matching with user defined filter.
  def userfilter
    begin
      @filter_rules.each do |filter|
        #Matching.
        if filter.condition.call(@mailobj)
          filter.proc.call(@mailobj)
        end
      end
    rescue
      if @maildeliv_conf[:FilterLog]
        File.open(@maildeliv_conf[:FilterLog], "a") do |f|
          f.puts Time.now.to_s
          f.puts [ $!.to_s, $!.backtrace.first ]
        end
      else
        STDERR.puts ["***User Filter Error***", Time.now.to_s]
        STDERR.puts [ $!.to_s, $!.backtrace.first ]
      end
    end
  end
  
  #Spam check with spamassasin
  #Currently, ignored this.
  def spamcheck
    nil
  end
  
  # Save to default folder.
  def defaultsaving
    savemail(@maildeliv_conf[:DefaultRule].call(@mailobj), true)
  end
end

MailDeliver.new