require 'drb/drb'

uri="druby://localhost:8585"

if ARGV.include?('--service')
  DRb.start_service(uri, OpenRobot)
  DRb.thread.join
else
  DRb.start_service
  Object.const_set :OpenRobotServer, DRbObject.new_with_uri(uri)
end