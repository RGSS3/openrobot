require 'lib/ls'
require 'json'
module OpenRobot
  module Command
    def self.do_get str
      _NO_KEY       = "没有需要获取的值"
      _KEY_ONLY_DOT = "不能以点号(.)为键值"
      _NO_VALUE     = "目标值未被设定"

      return _NO_KEY if str.nil?

      lkey = str.strip
      return _NO_KEY if lkey.empty?

      keys = lkey.split ?.
      return _KEY_ONLY_DOT if keys.empty?

      value = LocalStorage.get 'glob', keys
      return _NO_VALUE if value.nil?

      if value.is_a? Hash
        lkey + ?= + ?\n + JSON.pretty_generate(value)
      else
        lkey + ?= + value.to_s
      end
    end
  end
end
