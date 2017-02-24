module OpenRobot
  module Command
    def self.do_edit(str)
      _INVALID_FORMAT   = "编辑格式不对啦！"
      _NO_PERMISSION    = "你不能改这个请求哦~"
      _NO_REQUEST_FOUND = "哎呀，没有找到你要的那个请求！"

      if str =~ /\A(.*)\n([\w\W]*)\Z/
        id, content = $1, $2
        user_id = OpenRobot.current[3]
        oreq = Request.execute("select id, user_id from request where id = ?", id)
        return _NO_REQUEST_FOUND if oreq.empty?
        oreq = oreq[0]
        return _NO_PERMISSION unless user_id == oreq[1] || Privilege.find_user_group(user_id).include?(1)
        Request.execute 'delete from runtime_scripts where id = ?', id
        OpenRobot.current[3] = oreq[1]
        do_request content
        OpenRobot.current[3] = user_id
      else
        _INVALID_FORMAT
      end
    end
  end
end
