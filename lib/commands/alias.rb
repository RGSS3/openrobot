module OpenRobot
  module Command
    def self.do_alias(str)
      result = OpenRobot::Command::Request.execute("select id from request where user_id=? order by id desc limit 1", OpenRobot.current[3]).flatten
      if !result.empty?
        request_id = result[0]
        Request.execute("insert into request_alias values(?, ?, ?)", request_id, OpenRobot.current[3], str.strip)
        "OK: #{str.strip}"
      else
        "你还没有发起请求"
      end
    end 
  end
end