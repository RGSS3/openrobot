module OpenRobot
  module Command
    def self.do_show_priv str
      _WRONG_QQ = "森莫鬼啦"
      _NO_PRIV  = "噗噗噗，这谁啊，啥都干不了哦"
      str = str.strip
      return _WRONG_QQ unless str =~ /^\d{6,13}$/
      privs = Privilege::Entity::execute("select * from privilege").to_h
      res = Privilege.find_user_all_priv(str).map(&privs).join ?,
      res.empty? ? _NO_PRIV : res
    end
  end
end
