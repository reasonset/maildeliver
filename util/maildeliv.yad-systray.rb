#!/usr/bin/ruby

class YadSystrayCmd
  def initialize
    self.instance_eval(File.read(ENV["maildeliv_conf"] || "#{ENV["HOME"]}/.yek/maildeliv/maildelivrc.rb")) # To use configuration file.
    @memofile = (ENV["maildeliv_tempdir"] || @maildeliv_conf[:TempDir] || "#{ENV["HOME"]}/tmp/recv-mails") + ".summery"
    @zenitylist = (ENV["maildeliv_tempdir"] || @maildeliv_conf[:TempDir] || "#{ENV["HOME"]}/tmp/recv-mails") + ".yad"

    if system("zenity", "--list", "--width=650", '--title=Maildeliver Notification', '--column=From', '--column=Date', '--column=Subject', *File.foreach("/home/aki/tmp/recv-mails.yad").to_a)
      File.open("/home/aki/tmp/recv-mails.summery", "r+") do |f|
        f.flock(File::LOCK_EX)
        f.seek(0)
        f.truncate(0)
      end
    end
  end
end

YadSystrayCmd.new
