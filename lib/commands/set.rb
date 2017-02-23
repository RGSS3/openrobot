module OpenRobot
  module Command
    def self.do_set str
      _NO_KEY       = "没有需要设置的值"
      _KEY_ONLY_DOT = "不能以点号(.)为键值"
      _DONE         = "已记录"
      _DELETED      = "已删除"

      lkey, value = str.split ?\s
      return _NO_KEY if lkey.nil?

      keys = lkey.split ?.
      return _KEY_ONLY_DOT if keys.empty?

      require 'lib/ls'
      LocalStorage.set 'glob', keys, value

      if value.nil?
        _DELETED + ?\s + lkey
      else
        _DONE + ?\s + lkey + ?= + value
      end
    end
  end
end
