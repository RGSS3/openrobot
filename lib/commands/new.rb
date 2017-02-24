module OpenRobot
  module Command
    def self.do_new(str)
      if str =~ /(\S+)\s*(\S+)/
        type, entity = $1, $2, $3
        case type
        when "permission"
          Privilege.new_privilege(entity)
          "OK: #{str}"
        when "group"
          Privilege.new_group(entity)
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