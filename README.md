# Mail Deliver

Mail Ddlivering filter tool

## Dependency

* Ruby
    * Mail Gem
    * Oj Gem
* Dovecot (Optional)
* SpamAssassin (Optional)
* Systemd (Optional)

## Model and Design

Maildeliver called as filter.

Maildeliver reads mail from STDIN, routing filters, and pass to LDA program.
They are customizable.

## Install

* Copy `bin/*` to on your path.
* Write `/etc/maildeliver/maildeliver.rb`. I recommend to start with `cp config/maildeliver.rb /etc/maildeliver/`.
* Optionally, write `/etc/maildeliver/basic.yaml`.
* Create queue directories.
* Optionally, `cp systemd/maildeliver.service /etc/systemd/system/`, edit to fit your environment, and start and enable it.

### Creating queue directory

Maildeliver uses `/var/maildeliver` by default (you can override with `spooldir`.)
For exmaple;

```
# mkdir -p /var/maildeliver/{queue,error,unreadable}
# chmod 777 /var/maildeliver/{queue,error,unreadable}
```

## Usage

### Starting server

```
maildeliver.rb
```

Starting maildeliver server.

### Process email

```
maildeliver-q.rb <original> <selector> < email
```

`maildeliver-q.rb` reads email from STDIN, and pass to maildeliver server.

If you want to use this as Postfix local(8) alias command, you can use like

```aliases
haruka: |"/usr/local/bin/maildeliver.rb haruka haruka@exmaple.com"
```

Notice: Postfix alias command is execused with `nobody` user with private `/tmp`.

## Configuration

`maildeliver.rb` is a Ruby library.

### maildeliver.rb

#### Filtering

`$mdfilter` is mail filtering object.
You can set filtering proc like:

```ruby
$mdfilter.filter_procs.push ->(data, mail) {
  IO.popen("foofilter", "w") do |io|
    io.write data["mail"]
  end

  unless $?.zero?
    data["spam"] = true
  end
}
```

`data` object is a Hash.

|Key|Type|Description|
|-------|----|-----------------------|
|`mail`|`String`|Mail full string|
|`original`|`String`|maildeliver-q.rb's 1st argument|
|`selector`|`String`|maildeliver-q.rb's 2nd argument|
|`proxy`|`MailProxy`|Object has some check method.|
|`drop`|`Boolean`|Request to drop this mail|
|`save`|`Boolean`|Request to save without applying more filter|
|`spam`|`Boolean`|Mark as spam|
|`folder`|`String`|Set folder name|

`data["proxy"]` has some method for custom filtering.

|Method|Argument|Description|
|------|--------|-----------------------|
|`from?`|`glob`|return true if any from address matches glob pattern.|
|`to?`|`glob`|return true if any to address matches glob pattern.|

`mail` is a `Mail` (Ruby gem) object.

MailDeliver has SpamAssassin filter.
You can you like:

```ruby
$mdfilter.filter_procs.push $mdfilter.method(:filter_spamc)
```

#### Delivering

You can set proc how to deliver mail.

```ruby
$mdfilter.deliver_proc = ->(data) {
  IO.popen(["foodeliver", data["selector"]], "w") {|io| io.write data["mail"]}
}
```

MailDeliver has some delivering method.

```ruby
$mdfilter.deliver_proc = $mdfilter.method(:deliver_dovecot)
```

Use dovecot-lda (`/usr/lib/dovecot/deliver`).
`selector` is used as `-d` option's argument.
`folder` is used as `-m` option's argument.

If spam flag is set, add `-m Junk` argument.

```ruby
$mdfilter.deliver_proc = $mdfilter.method(:deliver_mh)
```

Put MH mail folder.

if `folder` is set, put there under `inbox`.

if spam flag is set, put spam floder.

`$mdfilter.options[:mh_folder_spam]` is path to Spam folder. `/` means MH Mailbox root. `/Junk` is default.

`$mdfilter.options[:mh_box]` is path to MH Mailbox. `~/Mail` is default.

#### Options

##### `$mdfilter.spam_folder_name`

Spam folder name (`Junk` is default.)

##### `$mdfilter.drop_on_spam`

If it is set, immidiately drop mail when spam flag is set.

##### `$mdfilter.error_on_filter`

How to do when filter raises exception.

`:drop` - Drop (remove) email immidiately.

`:save` - Save email immidiately.

`:spam` - Mark as spam.

`:ignore` - Do nothing and continue.

### basic.yaml

#### `tcpport` (Integer)

TCP Port number.
`10751` is default.

#### `use_unixsock` (Boolean)

If true, maildeliver uses Unix Domain Socket instread of TCP.

#### `sockpath` (File path)

Unix Domain Socket file path.

This option is effective only if use_unixsock is enabled.

`/tmp/maildeliver.sock` is by default.

#### `spooldir` (File path)

Base directory path for maildeliver uses.

`/var/maildeliver` is by default.

#### `keep_log_into` (File path)

maildeliver-q outs log into the directory.

#### `error_keep_into` (File path)

maildeliver-q outs queuing mail object into the directory on error.

`maildeliver-q-retry.rb` resends these mails.

#### `always_keep_into` (File path)

maildeliver-q outs queuing mail object into the directory before pass to maildeliver server.


