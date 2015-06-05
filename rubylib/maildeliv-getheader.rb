#!/usr/bin/ruby
# -*- mode: ruby; coding: UTF-8 -*-
require 'nkf'

module GetHeader
  def getaddr(mailobj)
    ###DEBUG### 
    #p mailobj
    ###########
    to = extract_addr(mailobj["TO"])
    from = extract_addr(mailobj["FROM"])
    in_k = nil
    
    if @maildeliv_conf[:MyAddress].any? {|k, v| in_k =k; File.fnmatch(v, from) }
      mailobj.direction = :send
      mailobj.address = to
      mailobj.in = in_k
      
    elsif @maildeliv_conf[:MyAddress].any? {|k, v| in_k =k; File.fnmatch("*" + v + "*", (mailobj["TO"] || "") ) }
      mailobj.direction = :recieve
      mailobj.address = from
      mailobj.in = in_k
      
    else
      
      mailobj.direction = :unknown
      mailobj.address = from
      mailobj.in = nil
    end
    
    mailobj.domain = ( mailobj.address && mailobj.address != "" ? mailobj.address[/@(.*)/, 1] : "UnknownDomain" )
    mailobj
  end
  
  def extract_addr(f)
    if f =~ /(?:[^"<]*(?>"[^"]*"))*<([^>]+)>/ # Do From term have NAME<addr> format?
      address = $1.delete("\" \t:<>;[]*/")
    elsif f =~ /[-_.,+a-zA-Z0-9+]+@[-a-zA-Z0-9.]+/ #Search e-mail address form.
      address = $&.delete("\" \t:<>;[]*/")
    else
      address = f.delete("\" \t:<>/;[]*")
    end
    
    address
  end
    

  def getheader(mailstr)
    
    mailobj = Hash.new
    headerlines = Array.new
    
    # Header to UTF-8, concat multiline term, and push headerlines Array.
    head, body = NKF.nkf( "-w -Lu -m", mailstr ).split(/\r?\n\r?\n/, 2)
    head.each_line do | l |
      if l =~ /^\s*$/
        break
      elsif l =~ /^\s+/
        headerlines.last.concat(l.lstrip)
      else
        headerlines.push(l)
      end

    end
    
    headerlines.each do |i|
      if i =~ /\A([-_A-Za-z0-9]+)\s*:/ # match header format?
        mailobj[$1.upcase] = $'.strip
      else
        next
      end
    end
    
    #Treat for TO/FROM for it is considered always exist.
    mailobj["TO"] ||= "UNKNOWN"
    mailobj["FROM"] ||= "UNKNOWN"
    mailobj["TO"] = "UNKNOWN" if mailobj["TO"].empty?
    mailobj["FROM"] = "UNKNOWN" if mailobj["FROM"].empty?
    
    
    class <<mailobj
      attr_accessor :mailstr
      attr_accessor :direction
      attr_accessor :address
      attr_accessor :domain
      attr_accessor :in
      attr_accessor :body
      attr_accessor :head
      attr_accessor :list
      attr_accessor :spam
      attr_accessor :spamlv
    end
    
    mailobj.mailstr = mailstr
    mailobj.head = head
    mailobj.body = body
    
    #Get Mailing List ID
    if lid = mailobj["LIST-ID"]
      lid =~ /"([^"]+)" *<.*?>/ or lid =~ /([^"]+) *<.*?>/ or lid =~ /<(.*?)>/ or lid =~ /\s*(.*)\s*/
      mailobj.list = $1.delete('"<>/!?\\')

    else
      mailobj.list = nil
    end
    

    mailobj
  end
end