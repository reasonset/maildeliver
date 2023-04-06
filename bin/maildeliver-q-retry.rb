#!/usr/bin/env ruby
require 'yaml'
require 'socket'

CONFIG = {
  "sockpath" => "/tmp/maildeliver.sock",
}

if File.exist?("/etc/maildeliver/basic.yaml")
  CONFIG.merge! YAML.load(File.read("/etc/maildeliver/basic.yaml"))
end

unless CONFIG["error_keep_into"]
  abort "No error_keep_into set."
end

Dir.children(CONFIG["error_keep_into"]).each do |msg|
  STDERR.puts "Took message #{msg}"
  json = File.read(File.join(CONFIG["error_keep_into"], msg))

  if CONFIG["use_unixsock"]
    UNIXSocket.open(CONFIG["sockpath"]) {|sock| sock.write json }
  else
    sock = TCPSocket.open("localhost", (CONFIG["tcpport"] || 10751))
    sock.write json
    sock.close
  end

  STDERR.puts "Delivered."
end
