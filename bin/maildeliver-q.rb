#!/usr/bin/env ruby

begin
  original = nil
  selector = nil
  mail = nil
  msg_id = nil
  envelope = nil

  begin
    require 'yaml'
    require 'oj'
    require 'socket'
    require 'securerandom'

    CONFIG = {
      "sockpath" => "/tmp/maildeliver.sock",
    }
    
    if File.exist?("/etc/maildeliver/basic.yaml")
      CONFIG.merge! YAML.load(File.read("/etc/maildeliver/basic.yaml"))
    end

    original = ARGV.shift
    selector = ARGV.shift
    mail = $stdin.read
    msg_id = SecureRandom.uuid

    envelope = Oj.dump({
      "original" => original,
      "selector" => selector,
      "mail" => mail
    })
  rescue => e
    $stderr.puts e.full_message
    $stderr.puts "Could't setup maildeliver queue, exit."
    exit 0
  end

  begin
    if CONFIG["keep_log_into"]
      $stderr = File.open(File.join(CONFIG["keep_log_into"], (Time.now.strftime("%Y%m%d_%H%M%S-") + msg_id + ".log")), "w")
    end

    $stderr.puts "Message ID is #{msg_id}"

    if CONFIG["always_keep_into"]
      File.open(File.join(CONFIG["always_keep_into"], (msg_id + ".json")), "w") do |f|
        f.puts envelope
      end
    end

    send_proc = ->(sock) {
      sock.write envelope
    }

    if CONFIG["use_unixsock"]
      UNIXSocket.open(CONFIG["sockpath"], &send_proc)
    else
      sock = TCPSocket.open("localhost", (CONFIG["tcpport"] || 10751))
      send_proc.(sock)
      sock.close
    end
  rescue => e
    begin
      $stderr.puts e.full_message
      $stderr.puts "Message #{msg_id} is not queued."
      if CONFIG["error_keep_into"]
        File.open(File.join(CONFIG["error_keep_into"], (msg_id + ".json")), "w") do |f|
          f.puts envelope
        end
      end
    rescue => e
      $stderr.puts e.full_message
    end
  else
    $stderr.puts "Message #{msg_id} is delivered."
  end
rescue => e
  $stderr.puts e.full_message
  exit 0
end
