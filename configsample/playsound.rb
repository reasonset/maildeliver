#!/usr/bin/ruby
# -*- mode: ruby; coding: UTF-8 -*-

@sound_rules = [
  Match["#{ENV["HOME"]}/.yek/maildeliv/mailsound/yougotmail.flac", ->(h,d) { d[:address].keys.any? {|i| i.include?("@example.com") }  }]
]

@default_sound = "#{ENV["HOME"]}/.yek/maildeliv/mailsound/default.wav"