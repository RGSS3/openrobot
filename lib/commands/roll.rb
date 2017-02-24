module OpenRobot
  module Command
    def self.do_roll(str)
      rand((Float(str) rescue Integer(str) rescue 0)).to_s
    end
  end
end