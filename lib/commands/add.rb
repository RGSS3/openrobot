module OpenRobot
  module Command
    def self.do_add(str)
      if str =~ /(\S+)\s*(\S+)/
        user_id, group = $1.to_i, $2
        Privilege.add_user user_id, group 
        "OK: #{str}"
      else
        "Error 99: Invalid Format"
      end
    rescue Privilege::Error
      $!.message
    end
  end
end