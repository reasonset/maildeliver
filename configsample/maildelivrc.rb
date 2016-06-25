#!/usr/bin/ruby
# -*- mode: ruby; coding: UTF-8 -*-
@maildeliv_conf = {
  MH: (ENV["MH"] || "#{ENV["HOME"]}/Mail"),
  MyAddress: {
              "example" => "foo@example.com",
              "second" => "baz-*@example.com"
            },
  VirusIsolation: "isolate", #Threat folder
  SpamIsolation: "junk", #Spam folder
  FilterLog: nil, #Path to error log in user defined filter rules.
  DefaultRule: ->(mail) { "inbox/address/#{mail.in || "Default"}/#{mail.domain || mail.address }/#{mail.address}" },
  ModuleDir: "#{ENV["HOME"]}/rubylib", #Ruby require path.
  TempDir: "#{ENV["HOME"]}/tmp/recv-mails", #place in temporary files.
  BeforePlugins: [],
  AfterPlugins: [],
  AntiSpamCommand: "/usr/bin/vendor_perl/spamc",
  RefuseXSpam: false,
  SpamProcAlternate: nil,
  LeaveHeaders: false, #Keep cumulatively log. This takes more time and RAM. Some plugins need to turn on this.
}
