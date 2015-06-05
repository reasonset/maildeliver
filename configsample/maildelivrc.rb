#!/usr/bin/ruby
# -*- mode: ruby; coding: UTF-8 -*-
@maildeliv_conf = {
  MH: (ENV["MH"] || "#{ENV["HOME"]}/Mail"),
  MyAddress: {
              "example" => "foo@example.com",
              "second" => "baz-*@example.com"
              },
  VirusIsolation: "isolate",
  SpamIsolation: "junk",
  FilterLog: nil,
  DefaultRule: ->(mail) { "inbox/address/#{mail.in || "Default"}/#{mail.domain || mail.address }/#{mail.address}" },
  ModuleDir: "#{ENV["HOME"]}/rubylib",
  TempDir: "#{ENV["HOME"]}/tmp/recv-mails",
  BeforePlugins: [],
  AfterPlugins: [],
  AntiSpamCommand: "/usr/bin/vendor_perl/spamc",
  RefuseXSpam: false,
  SpamProcAlternate: nil
}