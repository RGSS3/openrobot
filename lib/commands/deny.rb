module OpenRobot
  module Command
    def self.do_deny(str)
      if str =~ /(\S+)\s*(\S+)\s*(\S+)/
        type, entity, priv = $1, $2, $3
        case type
        when "user"
          Privilege.deny_user($2.to_i, $3)
          "OK: #{str}"
        when "group"
          Privilege.deny_group($2, $3)
          "OK: #{str}"
        end
      else
        "Error 99: Invalid Format"
      end
    rescue Privilege::Error
      $!.message
    end
  end
end