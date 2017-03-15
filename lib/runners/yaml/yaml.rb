require 'yaml'
module OpenRobot
  module Runners
    module YAML
      def self.do_script(script)
        y = YAML.load script
        
      end
    end
  end
end