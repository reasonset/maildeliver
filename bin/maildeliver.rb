#!/usr/bin/ruby
# -*- mode: ruby; coding: UTF-8 -*-
require 'thread'
require 'socket'
require 'securerandom'
require 'oj'
require 'mail'
require 'fileutils'
require 'yaml'

module MailDeliver
  class MailFilter
    SPAM_STATUS_RE = Regexp.new('^x-spam-status: .*?(yes|no)', Regexp::IGNORECASE)
    MAIL_HEADER_RE = /\n\n/
    def initialize
      @deliver_proc = self.method(:deliver_dovecot)
      @filter_procs = []
      
      @options = {}
      @spam_folder_name = "Junk"
      @drop_on_spam = false

      # :drop ... Remove email.
      # :save ... Save email.
      # :spam ... Mark as spam.
      # :ignore ... Skip errored filter.
      @error_on_filter = :ignore
    end
    
    attr :deliver_proc, true
    attr :filter_procs
    attr :options
    attr :spam_folder_name, true
    attr :drop_on_spam, true
    attr :error_on_filter, true

    # Preset Dovecot-LDA deliver proc.
    # It is used by default.
    def deliver_dovecot data
      cmd = ["/usr/lib/dovecot/deliver", "-d", data["selector"]]
      if data["spam"]
        cmd += ["-m", @spam_folder_name]
      elsif data["folder"]
        cmd += ["-m", data["folder"]]
      end

      IO.popen(cmd, "w") do |io|
        io.write data["mail"]
      end
    end

    # Preset MH deliver proc.
    # You can use as `@deliver_proc = $mdfilter.method(:deliver_mh)`
    def deliver_mh data
      mh_box = @options[:mh_box] || "#{ENV["HOME"]}/Mail"
      spam_folder = @options[:mh_folder_spam] || "/Junk"
      folder = data['spam'] ? spam_folder : "/inbox" + (data['folder'] || "")
      
      dest_dir = [mh_box, folder].join("/")
      
      unless File.exist?(dest_dir)
        FileUtils.mkpath(dest_dir)
      end
      
      max = Dir.children(dest_dir).max_by {|i| i.to_i }&.to_i || 0
      mail_id = max + 1
      
      File.open([dest_dir, mail_id].join("/"), "w") do |f|
        f.write data["mail"]
      end
    end

    # Filter by SpamAssassin
    def filter_spamc data, mail
      filtered_mail = nil
      IO.popen("spamc", "w+") do |io|
        io.write data["mail"]
        io.close_write
        filtered_mail = io.read
      end
      filtered_headers = MAIL_HEADER_RE.match(filtered_mail)&.pre_match || filtered_mail
      spam_status = (SPAM_STATUS_RE.match(filtered_mail)&.[](1) || "no").downcase == "yes"
      data["mail"] = filtered_mail
      data["spam"] ||= spam_status
    end

    # Filter by Rspamd
    # NO IMPREMENTED.
    def filter_rspamd
    end
    
    def exec data, mail
      force_mode = nil
      @filter_procs.each do |proc|
        begin
          proc.(data, mail)
        rescue => e
          STDERR.puts "FILTER_ERROR"
          STDERR.puts e.full_message
          
          case @error_on_filter
          when :drop
            data["drop"] = true
          when :save
            data["save"] = true
          when :spam
            data["spam"] = true
          end
        end

        case
        when data["drop"]
          force_mode = :drop
          break
        when data["save"]
          force_mode = :save
          break
        when data["spam"] && @drop_on_spam
          force_mode = :drop
          break
        end
      end

      return if force_mode == :drop

      @deliver_proc.(data)
    end
  end
end

$mdfilter = MailDeliver::MailFilter.new
load '/etc/maildeliver/maildeliver.rb'

module MailDeliver
  CONFIG = File.exist?("/etc/maildeliver/basic.yaml") ? YAML.load(File.read("/etc/maildeliver/basic.yaml")) : {
    "sockpath" => "/tmp/maildeliver.sock",
    "spooldir" => "/var/maildeliver"
  }
  
  class MailProxy
    def initialize mail
      @mail = mail
    end
    
    attr :mail
    
    def from? glob
      @mail.from.any? do |addr|
        File.fnmatch?(glob, addr)
      end
    end
    
    def to? glob
      @mail.to.any? do |addr|
        File.fnmatch?(glob, addr)
      end
    end
  end
  
  class Server
    def initialize
      @queue = Queue.new
    end
    
    # Start queue server thread.
    def queue_server
      Thread.new do
        serv = UNIXServer.new(CONFIG["sockpath"])

        begin
          while s = serv.accept
            id = SecureRandom.uuid
            begin
              json = s.read
              File.open("#{CONFIG["spooldir"]}/queue/#{id}.json", "w") do |f|
                f.write json
              end
              @queue.push id
            ensure
              s.close
            end
          end
        ensure
          serv.close
          File.delete CONFIG["sockpath"]
        end
      end
    end

    # Filter each mail.    
    def filter data, mail
      $mdfilter.exec data, mail
    end
    
    # Take from queue, pass to filter.
    def filter_loop
      while id = @queue.shift
        begin
          json = File.read "#{CONFIG["spooldir"]}/queue/#{id}.json"
          data = Oj.load json
          mail = Mail.new data["mail"]
          filter(data, mail)
        rescue => e
          STDERR.puts e.full_message
          if data
            data["error"] = {
              "message" => e.message,
              "backtrace" => e.backtrace
            }
            File.open("#{CONFIG["spooldir"]}/error/#{id}.json", "w") {|f| Oj.dump(data, f) }
          elsif json
            File.open("#{CONFIG["spooldir"]}/error/#{id}.json", "w") {|f| f.write json }
          else
            File.open("#{CONFIG["spooldir"]}/unreadable/#{id}", "w") {|f| nil }
          end
        ensure
          File.delete "#{CONFIG["spooldir"]}/queue/#{id}.json"
        end
      end
    end
  end
end

md = MailDeliver::Server.new
md.queue_server
md.filter_loop