module OpenRobot
  module Command
    def self.do_edit(str)
      if str =~ /\A(.*)\n([\w\W]*)\Z/
        id, content = $1, $2
        user_id = OpenRobot.current[3]
        if !Request.execute("select id from request where user_id = ? and id = ?", user_id, id.to_i).empty?
          Request.execute("delete from runtime_scripts where id = ?", id)
          do_request(content)
        else
          return "Error 100: This request #{id} does not belong to you. #{user_id}"
        end
      else
        return "Error 99: Invalid Format"
      end
    end
  end
end