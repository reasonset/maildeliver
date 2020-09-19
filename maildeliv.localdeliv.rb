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
    op.on("-M", "--nomemo") {|v| @nomemo = true; ENV["maildeliv_nomemo"] = "true" }

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

    @memofile = sprintf("%s/%.2f.yaml", memodir, Time.now.to_f)
    headers = @mailobj.merge({"__address" => @mailobj.address })

    File.open(@memofile, "w") do |f|
      YAML.dump(headers, f)
    end unless @nomemo

    # Cumulatively log
    if @maildeliv_conf[:LeaveHeaders] && !@nomemo
      cumulatively = memodir + ".summery"
      unless File.exist? cumulatively
        File.open(cumulatively, "w") {|f| nil }
      end

      File.open(cumulatively, "r+") do |f|
        f.flock(File::LOCK_EX)
        db = (YAML.load(f) rescue nil)
        db ||= []

        db << headers
        f.seek(0)
        f.truncate(0)
        YAML.dump(db ,f)
      end
    end

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
    if @filtertestmode

      userfilter(true)

    else

      catch :filtering do
        ##### EXIT WITH throw :filtering #####

        clamcheck

        userfilter

        spamcheck

        defaultsaving

        ######################################
      end
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
        STDERR.puts ["\e[31m***User Filter Error***\e[0m", Time.now.to_s]
        STDERR.puts [ $!.to_s, $!.backtrace.first ]
        File.open(@maildeliv_conf[:FilterLog], "a") do |f|
          f.puts Time.now.to_s
          f.puts [ $!.to_s, $!.backtrace.first ]
        end
      else
        STDERR.puts ["\e[31m***User Filter Error***\e[0m", Time.now.to_s]
        STDERR.puts [ $!.to_s, $!.backtrace.first ]
      end
    end
  end

  #Spam check with spamassasin
  #Currently, ignored this.
  def spamcheck
    if spamfilter
      STDERR.puts "SpamFilter: SPAM"
      # Alternative Proc is exist?
      if @maildeliv_conf[:SpamProcAlternate]
        @maildeliv_conf[:SpamProcAlternate].call(@mailobj)
      else
        savemail("junk", false)
        destroymail()
        return true
      end
    else
      STDERR.puts "SpamFilter: NOTSPAM"
      return false
    end
  end

  # This method returns true if a mail judged as spam.
  def spamfilter
    if @mailobj["X-SPAM-FLAG"]
      # Unless @maildeliv_conf[:RefuseXSpam] is true,
      #   Check X-Spam-* header and use it.
#      if @maildeliv_conf[:RefuseXSpam]
#      else
        if @mailobj["X-SPAM-FLAG"].casecmp("yes") == 0
          mailobj.spam = true
          if @mailobj["X-SPAM-LEVEL"]
            mailobj.spamlv = @mailobj["X-SPAM-LEVEL"].length
          end
          return true
        else
          return false
        end
#      end
    end


    #Enabled?
    if @spam
      #Invoke @maildeliv_conf[:AntiSpamCommand] as spamassassin.
      IO.popen(@maildeliv_conf[:AntiSpamCommand], "w+") do |io|
        io.write @mailstr
        io.close_write

        spambody = io.gets(nil)

        # Replace Mailbody.
        if ! spambody.nil? && ! spambody.empty?
          @mailobj.mailstr = spambody
        end

      end

      serialized_mailbody = NKF.nkf( "-w -Lu -m", @mailobj.mailstr ).split(/\r?\n\r?\n/, 2).first

      #Get spam infomation
      if serialized_mailbody =~ /^X-Spam-Flag: (.*)/
        @mailobj.spam = ( $1.casecmp("yes") == 0 )
        if serialized_mailbody =~ /^X-Spam-Level: (.*)/
          @mailobj.spamlv = $1.length
        end
      end

    end

    return @mailobj.spam

  end

  # Save to default folder.
  def defaultsaving
    savemail(@maildeliv_conf[:DefaultRule].call(@mailobj), true)
  end
end

MailDeliver.new
