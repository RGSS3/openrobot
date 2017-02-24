module OpenRobot
  module Command
    def self.do_list(str)
      result = OpenRobot::Command::Request.execute("select id, content from request where user_id=?", (str || "").empty? ? OpenRobot.current[3] : str.to_i)
      result.map{|x| "==#{x[0]}==\n#{(x[1] || "").split("\n")[0, 3].join("\n")}"}.join("\n")
    end
  end
end