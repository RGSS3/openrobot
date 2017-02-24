module OpenRobot
  module Command
    def self.do_eval(str)
       ret = eval(str,TOPLEVEL_BINDING).to_s rescue $!.backtrace.unshift($!.to_s).join("\n")
       $last_eval = str
       ret
    end
  end
end