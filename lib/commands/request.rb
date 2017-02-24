#encoding: utf-8
require 'digest/md5'
module OpenRobot
  module Command
    Request = SQLite3::Database.new('database/request.db')
    def self.do_request(str)
      user_id = OpenRobot.current[3]
      hash = Digest::MD5.hexdigest(Time.now.to_s + rand(1048576).to_s)
      Request.execute "insert into request values (NULL, ?, ?, ?)", hash, str, user_id 
      id = Request.execute "select id from request where hash = ?", hash
      id = id.flatten[0]
      "OK: 已经存在请求 #{id} 中. 需要三个其他用户使用\n:vote #{id}\n命令来认可加入到运行时"
    rescue Exception
      $!.backtrace.unshift($!.to_s).join("\n")
    end

    def self._newbinding
      x = eval %{
       Module.new{
         def self.box
           binding
         end
       }
      }, TOPLEVEL_BINDING
      x.box
    end
    def self.do_reset(str)
      OpenRobot::PROCS.clear
      ret = []
      count = 0
      error = 0
      Request.execute("select id from runtime_scripts").flatten.each{|x|
        next if !x
        hash, res, user_id = Request.execute("select hash, content, user_id from request where id = ?", x).flatten
        begin
           #eval "lambda{\n#{res}\n}.call", _newbinding, "<request:#{x}>", 1
           RubyVM::InstructionSequence.compile(res).eval
           count += 1
        rescue Exception
           Request.execute("delete from runtime_scripts where id = ?", x).flatten
           ret << "#{user_id} #{x}发生错误"
           error += 1
        end
      }
      ret << "#{count} 载入完成, #{error} 发生错误"
      $".delete_if{|x| x["/lib/command"]}
      ret.join("\n")
    rescue Exception
        $!.backtrace.unshift($!.to_s).join("\n")
         
    end

    def self.do_vote(str)
      hash = str.strip
      if hash.empty?
        return "Error 99: Invalid Format"
      end
      result = []
      if hash.index(" ")
        id, name = hash.split(" ")
        result = Request.execute("select id from request_alias where user_id = ? and name = ?", id.to_i, name).flatten
        if result.empty?
          user_id = OpenRobot.current[3]
          result = Request.execute("select id from request where (hash = ? or id = ?) and user_id != ?", hash, hash.to_i, user_id).flatten
        end
      end
      if result.empty?
          user_id = OpenRobot.current[3]
          result = Request.execute("select id from request where (hash = ? or id = ?) and user_id != ?", hash, hash.to_i, user_id).flatten
      end
      if result.empty?
        return "Error 200: can't find request #{str}"
      else
        request_id = result[0]
        result2 = Request.execute("select id from vote where request_id = ? and user_id = ?", request_id, user_id).flatten
        if !result2.empty?
           return "Error 201: you have voted to request #{str} #{user_id}"
        end
        result2 = Request.execute("select id from vote where request_id = ?", request_id).flatten
        result3 = Request.execute("insert into vote values (NULL, ?, ?)", request_id, user_id)
        if result2.size + 1 == 3
           Request.execute("insert into runtime_scripts values (?)", request_id)
           return "OK: #{hash} 已经添加到运行时"
        elsif result2.size + 1 < 3
          return "投票(#{result2.size + 1} / 3)"
        else 
          return "没必要投票了"
        end
      end
      "投票失败"
    end


=begin
    def self.purge(str)
      hash = str.strip
      user_id = OpenRobot.current[3]
      result = Request.execute("select id from request where hash = ? and user_id != ?", hash, user_id).flatten
      if result.empty?
        return "Error 200: can't find request #{str}"
      end
      request_id = result[0]
      Request.execute("delete from runtime_scripts where id = ?", request_id)
      "OK: 已经从运行时删除脚本"
    end
=end
  end
end