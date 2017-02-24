module OpenRobot
  module Command
    def self.do_sa_vote str
      _INVALID_FORMAT   = "给窝一个请求 id 啦！"
      _NO_REQUEST_FOUND = "呜~没有找到这个请求: %s"
      _DONE             = "诶嘿~~~ %s 已经添加到运行时"

      return _INVALID_FORMAT unless str.strip =~ /^(\d+)/
      request_id = str.strip.split(/\s+/)[0]

      request = Request.execute 'select id from request where id = ?', request_id
      request = request.flatten
      return _NO_REQUEST_FOUND % request_id if request.empty?

      Request.execute 'insert into runtime_scripts values (?)', request_id
      _DONE % request_id
    rescue Object
      $!.backtrace.unshift($!.to_s).join("\n")
    end
  end
end
