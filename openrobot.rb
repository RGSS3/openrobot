#encoding: utf-8
$: << File.dirname(File.expand_path(__FILE__))
require 'digest'
require 'win32api'
require 'lib/s30.rb'
=begin
$" << "digest/md5"

module Digest
  class MD5
    extend Seiran30
    def self.hexdigest(str)
      md5 str
    end
  end
end
=end

require 'lib/core/privilege'
require 'lib/core/event'
require 'lib/core/resource'
module OpenRobot
  module Command
    Request = []
  end
end

require 'lib/core/shortcut'
require 'lib/core/service'