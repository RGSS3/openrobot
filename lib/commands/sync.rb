module OpenRobot
  module Command
    def self.do_sync(str)
        ret = [`cd OpenRobot & git pull  2>&1`]
        $".delete_if {|x| x[/OpenRobot/] }
	OpenRobot::PROCS.clear
	require 'openrobot'
        ret.join("\n")
    end
  end
end