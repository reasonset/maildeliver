#!/usr/bin/env ruby
require 'yaml'
require 'oj'
require 'socket'

CONFIG = File.exist?("/etc/maildeliver/basic.yaml") ? YAML.load(File.read("/etc/maildeliver/basic.yaml")) : {
  "sockpath" => "/tmp/maildeliver.sock",
}

original = ARGV.shift
selector = ARGV.shift
mail = STDIN.read

UNIXSocket.open(CONFIG["sockpath"]) do |sock|
  sock.write Oj.dump({
    "original" => original,
    "selector" => selector,
    "mail" => mail
  })
end