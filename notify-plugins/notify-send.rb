#!/usr/bin/ruby
# -*- mode: ruby; coding: UTF-8 -*-

class NotifySend
  ARGS = StandardNotify::ARG
  
  def initialize
    @mode = case ARGS["notify-send"]
      when "total"
        :total
      else
        nil
      end
      
    @use = if ARGS["ns-use-from"]
        :from
      else
        :address
      end
      
  end
  
  def fire(headers, db)
    
    str = nil
    
    case
    when @mode == :total
      str = "Total " + db[:number].to_s + " mails."
    else
      str = db[@use].map{|k, v| "%s: %d" % [k, v] }.join("\n")
    end
        
      
    
    system "notify-send", "-a", "MAIL DELIVER", "You got mail(s)",  str
  end
  
end

StandardNotify::PLUGINS << NotifySend.new