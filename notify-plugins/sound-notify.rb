#!/usr/bin/ruby
# -*- mode: ruby; coding: UTF-8 -*-


class SoundNotify
  ARGS = StandardNotify::ARG
  
  def initialize
    get_sound_rule
  end
   
  def get_sound_rule
    self.instance_eval(File.read(ENV["maildeliv_soundrules"] ||"#{ENV["maildeliv_confdir"] ||  ENV["HOME"]}/.yek/maildeliv/playsound.rb"))
  end
  
  def fire(headers, db)
    if ARGS["silent"]
      return nil
    end
      
    catch :played do
      @sound_rules.each do |i|
        i.match(headers, db)
      end
      
      system "play", @default_sound if @default_sound
    end
  end
  
  class Match
    def self.[](soundfile, rule)
      self.new(soundfile, rule)
    end
    
    def initialize(soundfile, rule)
      @play = soundfile
      @rule = rule
    end
    
    def match(headers, db)
      if @rule.call(headers, db)
        system "play", @play
        throw :played
      end
    end
    
  end
end

StandardNotify::PLUGINS << SoundNotify.new