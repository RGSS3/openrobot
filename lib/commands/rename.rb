module OpenRobot
  module Command
    def self.do_rename(str)
      user_id = OpenRobot.current[3]
      str=str.to_s.strip
      return "Error 99: Invalid format" if(str.empty?) 
      result = Privilege::Entity.execute "select id from user where name = ? and id != ? ", str, user_id
      if result.empty?
        Privilege::Entity.execute "update user set name = ? where id = ?", str, user_id
        "OK: You are now #{str}"
      else
        "Error 110: #{str} exists"
      end
    end
  end
end