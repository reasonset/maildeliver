#!/usr/bin/ruby

class YadSystrayCmd
  def initialize
    self.instance_eval(File.read(ENV["maildeliv_conf"] || "#{ENV["HOME"]}/.yek/maildeliv/maildelivrc.rb")) # To use configuration file.
    @memofile = (ENV["maildeliv_tempdir"] || @maildeliv_conf[:TempDir] || "#{ENV["HOME"]}/tmp/recv-mails") + ".summery"
    @yadlist = (ENV["maildeliv_tempdir"] || @maildeliv_conf[:TempDir] || "#{ENV["HOME"]}/tmp/recv-mails") + ".yad"

    if system("yad", "--list", "--width=650", "--height=500", '--top', '--title=Maildeliver Notification', '--column=From', '--column=Date', '--column=Subject', *File.foreach(@yadlist).map {|i| i.gsub('&', '&amp;')}.map {|i| i.gsub('<', '&lt;')} )
      File.open(@memofile, "r+") do |f|
        f.flock(File::LOCK_EX)
        f.seek(0)
        f.truncate(0)
      end
    end
  end
end

YadSystrayCmd.new
