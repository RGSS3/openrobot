module OpenRobot
  module Command
    def self.do_show(str)
      hash = (str || "").strip
      if hash.empty?
        return "Error 99: Invalid Format"
      end
      if hash.index(" ")
        user_id, name = hash.split(" ")
      else
        user_id = OpenRobot.current[3]
        name = hash
      end
      result = Request.execute("select id, content from request where hash = ? or id = ?", name, name.to_i)
      if result.empty?
        result = Request.execute("select id from request_alias where user_id = ? and name = ?", user_id.to_i, name)
        result = OpenRobot::Command::Request.execute("select id,content from request where id=? order by id desc limit 1", result[0])
      end
      if !result.empty?
        result.map{|x|
           x[1]
        }.join("\n\n")
      else
        "没有结果 #{str}"
      end
    end 
  end
end