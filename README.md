Mail Deliver 2
===========

MDA with programmable filter for MH mail folders.

## Dependency

This porgram requires Ruby >= 2.0.

Utility scripts need also fetchmail.

Sound notification script uses `play` (SOX.)

Display notification script uses `notify-send`.

## Install

* Copy maildeliver.localdeliv.rb to your program directory (e.g. /usr/local/bin.)
* If you want to use utility programs, files in util directory too.
* Copy configsample directory to ~/.yek/maildeliver.
* Copy files in rubylib derectory to your ruby librariy's directory,
  or anywhere you want and write it on configuration file.
* Copy files you want in notify-plugins directory to ~/.yek/maildeliv/notify-plugins.

for example

	$ sudo cp maildeliver.localdeliv.rb util/* /usr/local/bin/
	$ sudo cp -R configsample ~/.yek/maildeliv
	$ [[ -e "$(ruby -e 'puts $:[1]')" ]] || mkdir -p "$(ruby -e 'puts $:[1]')"
	$ cp rubylib/* "$(ruby -e 'puts $:[1]')"/
	$ mkdir ~/.yek/maildeliv/notify-plugins
	$ cp -R notify-plugins/{sound-notify.rb,notify-send.rb} ~/.yek/maildeliv/notify-plugins/


## Configuration

You should to configurate files in `~/.yek/maildeliver`.

### maildeliverrc.rb

`maildeliverrc.rb` is a basic settings for your MailDeliver MDA.

#### MH

Your MH folder path.

Normally, you don't need to change this value.

#### MyAddress

Your e-mail alias name and e-mail address.

Alias name is used as part of file path,
so you may not use file path unuseful character.

You can use shell wild cards for e-mail address.

#### VirusIsolation

Folder path for a mail considered as virus.

#### SpamIsolation

Folder path for a mail considered as spam.

Currently, spam filter is disabled.

#### FilterLog

If set, you can log to this path that some error in your filter rules.
Else some error is output to STDERR.

#### DefaultRule

Mail folder for a mail unmatched in user defined filter.

This value is a Proc object.

This Proc takes a argument as Mail Object,
and this Proc should return path of default folder.

#### ModuleDir

Additional ruby library's directory for MailDeliver ruby libraries.

#### TempDir

Directory for saving header for notifications.

#### BeforePlugin

Unused.

#### AfterPlugin

Unused.

### mailfilter.rb

Define rules for sorting or filtering.

Filter struct takes two Procs.

First Proc is conditional Proc.
If this proc returns true, second proc will be called.

Every Proc is given a Mail Object argument.

Rules are tested from top.

`savemail(<folder>, [<exit>])` function save mail to <folder>.
If <exit> is true,  

`destroymail()` function last sorting this mail without saving.

### Mail Object

This is a Hash having uppercased mail header as key and the header value as value,
and added singleton methods.

	#in

Your mail alias.

	#address

(First) your partner's e-mail address in the mail.

	#domain

(First) your partner's e-mail domain in the mail.


	#direction

If your e-mail in From header, set `:send` to it.
Otherwise, set `:recieve`.

	#mailstr

Raw mail data.
If you modify it, it effects to saving mail.

	#body

Mail body without header.

## Usage

### MDA

Simply assain `maildeliver.localdelib.rb` as a MDA.

you can use options `-c` or ``--clam` is checking virus using ClamAV (`clamav - --quiet` command.)
`-a` or `--assasin` is checking spam using spamassasin, but currently this option don't work.

I suppose that localdelive is used in fetchmail.

### MailChecker

### Notification plugins

Notification plugins notifies on new mail delivered.

This function's core script is standard-notify.rb.
It calls scripts in plugin directory ( ~/.yek/maildeliv/notify-plugins by default.)

Normally, it is called by Mail Checker.

#### Notification script's objects

"headers" is mail header same as mailobj but

* No singleton method
* add `__address` key instead of mailobj.address

"db" is a Hash.

* :address -> { address -> num ... } #number per address
* :from -> { from(header) -> num ... } #number per from header's value
* :number -> num #total delivered in this time

#### Sound Notify

Sound notification script plays sound file with SOX play command on new mail delivered.

This plugins setting file is ~/.yek/maildeliv/playsound.rb.

	@sound_rules = [
 	  Match["#{ENV["HOME"]}/.yek/maildeliv/mailsound/yougotmail.flac", ->(h,d) { d[:address].keys.any? {|i| i.include?("@example.com") }  }]
	]
	
	@default_sound = "#{ENV["HOME"]}/.yek/maildeliv/mailsound/default.wav"

"Match" is

	Match[<soundfile>, ->(headers, db) { <matching code> } ]



If Match proc returns true, play <soundfile>.

Rules are tested from top and exit after first match.

If `silent` standard-notify option given, fire method return with do nothing.

#### Notify Send

Display graphcal notification with `notify-send`.

Supporting display modes are

##### summerize

You can control with `notyfy-send` option.

If `total` given, show total number of mails.

Otherwise, show numbers per sender.

##### Sender

Normally, it use address for sender identification.

If `ns-usr-from` option is set, use From header instead of address.

## Advanced Usage

### Sorter

You can use `maildelive.localdeliv.rb` as mail sorter.

If you add some sorting rules or some filters, and you got to want to arrange your confused Mailbox.
LocalDeliver helps you for sorting many e-mails.

It is very easy.Like thus

	$ mkdir Mail_sorted
	$ find Mail -type f -name "[1-9]*" | while read i; do MH=$HOME/Mail_sorted maildeliv.localdeliv.rb --nomemo < "$i"; done
	$ rm -rf Mail
	$ mv Mail_sorted Mail