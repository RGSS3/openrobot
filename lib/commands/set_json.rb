require 'lib/ls'
require 'json'
module OpenRobot
  module Command
    def self.do_set_json str
      _NO_KEY       = "没有需要设置的值"
      _KEY_ONLY_DOT = "不能以点号(.)为键值"
      _INVALID_JSON = "无效的 json"
      _DONE         = "已记录"

      return _NO_KEY if str.nil?

      str.match /(\S+)\s+([\s\S]+)/
      lkey = $1
      json = JSON.parse $2 rescue return _INVALID_JSON
      return _NO_KEY if lkey.nil?

      keys = lkey.split ?.
      return _KEY_ONLY_DOT if keys.empty?

      ovalue = LocalStorage.get 'glob', keys
      LocalStorage.set 'glob', keys, json

      _DONE + ?\s + lkey + ?= + ?\n + JSON.pretty_generate(json) + "\n(=" + ovalue.to_json + ?)
    end
  end
end
