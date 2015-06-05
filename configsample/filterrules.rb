#!/usr/bin/ruby
# -*- mode: ruby; coding: UTF-8 -*-

@filter_rules = [
  Filter[->(m) { m.address == "foo@example.com" }, ->(m) { savemail "inbox/Person/RandomLuser", true }],
  Filter[->(m) { m.mailstr.include?("nasty gram") }, ->(m) { destroymail }],
]