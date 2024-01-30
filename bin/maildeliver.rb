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
      @hooks = {}
      @spam_folder_name = "Junk"
      @drop_on_spam = false
      @feilter_timeout = 60

      # :drop ... Remove email.
      # :save ... Save email.
      # :spam ... Mark as spam.
      # :ignore ... Skip errored filter.
      @error_on_filter = :ignore
    end
    
    attr :hooks
    attr :deliver_proc, true
    attr :filter_procs
    attr :options
    attr :spam_folder_name, true
    attr :drop_on_spam, true
    attr :error_on_filter, true
    attr :filter_timeout, true

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

    # Sample deliver proc for development.
    # You can use as `@deliver_proc = $mdfilter.method(:deliver_sample)`
    def deliver_sample data
      pp({
        spam: data["spam"],
        folder: data["folder"],
        length: data["mail"].length
      })
    end

    # Filter by SpamAssassin
    def filter_spamc data, mail
      filtered_mail = nil
      IO.popen("spamc", "w+") do |io|
        io.write data["mail"]
        io.close_write
        filtered_mail = io.read
      end
      
      # SpamAssassin embeds DECODED mail body on mail.
      # When mail body is multibyte UTF-8 string, it may break UTF-8 sequence.
      filtered_headers = MAIL_HEADER_RE.match(filtered_mail.valid_encoding? ? filtered_mail : filtered_mail.encode("UTF-8", "UTF-8", invalid: :replace))&.pre_match || filtered_mail

      spam_status = (SPAM_STATUS_RE.match(filtered_headers)&.[](1) || "no").downcase == "yes"
      data["mail"] = filtered_mail
      data["spam"] ||= spam_status
    end

    # Filter by Rspamd
    # NO IMPREMENTED.
    def filter_rspamd
    end
    
    def exec data, mail
      STDERR.sprintf("Filter mail from %s", mail.from[0]) rescue nil

      force_mode = nil
      @filter_procs.each do |proc|
        begin
          Timeout.timeout(@feilter_timeout) do
            proc.(data, mail)
          end
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
          STDERR.printf("Mail from %s is force dropped.", mail.from[0]) rescue nil
          @hooks[:drop]&.(mail)
          force_mode = :drop
          break
        when data["save"]
          STDERR.printf("Mail from %s is force saved.", mail.from[0]) rescue nil
          force_mode = :save
          break
        when data["spam"] && @drop_on_spam
          STDERR.printf("Mail from %s is force dropped with drop_on_spam.", mail.from[0]) rescue nil
          force_mode = :drop
          break
        end
      end

      return if force_mode == :drop

      if data["spam"]
        STDERR.printf("Mail from %s is flagged as spam.", mail.from[0]) rescue nil
        @hooks[:spam]&.(mail)
      end

      @deliver_proc.(data)
    end
  end
end

$mdfilter = MailDeliver::MailFilter.new
load '/etc/maildeliver/maildeliver.rb'

module MailDeliver
  CONFIG = {
    "sockpath" => "/tmp/maildeliver.sock",
    "spooldir" => "/var/maildeliver"
  }
  if File.exist?("/etc/maildeliver/basic.yaml")
    CONFIG.merge! YAML.load(File.read("/etc/maildeliver/basic.yaml"))
  end
  
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
      existing_queue = Dir.children("#{CONFIG["spooldir"]}/queue")
      existing_queue.each do |i|
        id = File.basename(i, ".json")
        @queue.push(id)
      end
    end
    
    # Start queue server thread.
    def queue_server
      Thread.new do
        serv = CONFIG["use_unixsock"] ? UNIXServer.new(CONFIG["sockpath"]) : TCPServer.new("localhost", (CONFIG["tcpport"] || 10751))

        begin
          FileUtils.chmod(0666, CONFIG["sockpath"]) if CONFIG["use_unixpath"]
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
          File.delete CONFIG["sockpath"] if CONFIG["use_unixsock"]
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
        STDERR.puts "Dequeue: #{id}"
        begin
          json = File.read "#{CONFIG["spooldir"]}/queue/#{id}.json"
          data = Oj.load json
          mail = Mail.new data["mail"]
          data["proxy"] = MailProxy.new(data["mail"])
          filter(data, mail)
        rescue => e
          STDERR.puts e.full_message
          if data
            data["error"] = {
              "message" => e.message,
              "backtrace" => e.backtrace
            }
            File.open("#{CONFIG["spooldir"]}/error/#{id}.json", "w") {|f| f.write Oj.dump(data) }
            $mdfilter.hooks[:error_data_avilable]&.(data)
          elsif json
            File.open("#{CONFIG["spooldir"]}/error/#{id}.json", "w") {|f| f.write json }
            $mdfilter.hooks[:error_on_parse_json]&.(json)
          else
            File.open("#{CONFIG["spooldir"]}/unreadable/#{id}", "w") {|f| nil }
            $mdfilter.hooks[:error_unreadable]&.(id)
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