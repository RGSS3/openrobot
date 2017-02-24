module OpenRobot
    module Command
        def self.do_active_requests(str)
            Request.execute("select id from runtime_scripts").flatten.sort.to_s
        end
    end
end
