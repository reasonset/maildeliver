# Mail Deliver

Mail Ddlivering filter tool

## Requirement

* Ruby
* 

## Model and Design

Maildeliver called as filter.

Maildeliver reads mail from STDIN, routing filters, and pass to LDA program.
They are customizable.

## Install

* Copy `bin/*` to on your path.
* Write `/etc/maildeliver/maildeliver.rb`. I recommend to start with `cp config/maildeliver.rb /etc/maildeliver/`.

## Usage

```
maildeliver.rb <deliver-to> <selector>
```

`deliver-to` is mailbox parameter.
It is used for Dovecot LDA's `-d` agrument by default.

`selector` is original destination identity.

For exmaple, in `aliases` file.

```aliases
haruka: |"/usr/local/bin/maildeliver.rb haruka@exmaple.org haruka"
```

## Configuration

`maildeliver.rb` is a Ruby library.

### Filtering rules

Maildeliver calls `MAIL_FILTER_PROXY.filter.(mail)` for each mail.

`mail` is a `MailDeliver::MailProxy` object.

#### Global methods

#### MailProxy object

##### `from?(glob)`

Return `true` if any sender address matches glob.

##### `to?(glob)`

Return `true` if any destination address matches glob.

### Overrideing

#### Local MDA

`MAIL_FILTER.mda` (Proc) is called last phase on filtering.
