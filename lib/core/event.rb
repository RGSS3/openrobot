require 'timeout'
require 'thread'
module OpenRobot
  class << self
    attr_accessor :current
  end
  
  Store   = Struct.new :message, :env 
  Direct  = Struct.new :group_id, :message
  Defer   = Struct.new :info, :count, :handler, :session_id
  DeferedValue = Struct.new :obj
  Session = Struct.new :store, :handler, :clients, :mutex, :thread
  JoinSession = Struct.new :client
  PROCS    = {}
  DEFERED  = {}
  SESSIONS = {}
  TIMEOUT  = 1
  SESSION_ID = {value: 0}
 
  #todo 

  Intepreter = lambda{|value, info, handler, run, defer, session_id|
      case
      when String === value
        if session_id && SESSIONS[session_id]
          SESSIONS[session_id].store = nil
        end
        run << [info[:all][2], value.encode('gbk', 'utf-8', replace: '?')]
      when Store === value
        Intepreter.call(value.message, info, handler, run, defer, session_id)
        if session_id
          SESSIONS[session_id].store = value
        else
          SESSION_ID[:value] += 1
          session_id = SESSION_ID[:value]
          pair = [info[:all][2], info[:all][3]]
          SESSIONS[session_id] = Session.new value, handler, [pair], Mutex.new
          run << [info[:all][2], "session #{session_id} created"]
        end
      when NilClass === value
      when DeferedValue === value
          defer[value.obj] = Defer.new info, 1, handler, session_id
      when JoinSession === value
         if session_id
          SESSIONS[session_id].clients << value.client
        else
          SESSION_ID[:value] += 1
          session_id = SESSION_ID[:value]
          pair = [info[:all][2], info[:all][3]]
          SESSIONS[session_id] = Session.new value, handler, [pair, value.client], Mutex.new
          run << [info[:all][2], "session #{session_id} created"]
        end
      when Array === value
         value.each{|x|
            Intepreter.call(x, info, handler, run, defer, session_id)
         }
      
      else
         run << [info[:all][2], "不能理解的值 #{value.class.to_s}".encode('gbk', 'utf-8', replace: '?')]
      end
  }
  
  
  Runner = lambda{|handler, info, run, defer, session_id|
     begin  
       u = Thread.new{
         begin
           handler.call(info)
         rescue Exception
         end
       }.tap{|x| x.abort_on_exception = true }
       Timeout::timeout(TIMEOUT){
           t = Time.now
           while u.alive? && Time.now - t < TIMEOUT
             Thread.pass
           end
       }
     rescue Exception
     end 
    
     if u && u.alive?
       defer[u] = Defer.new info, 1, handler, session_id
     else
       Intepreter.call(u.value, info, handler, run, defer, session_id) if u.value
     end
  }

  DeferedRunner = lambda{|obj, run, defer, value| 
      begin  
       Timeout::timeout(TIMEOUT){
           t = Time.now
           while obj.alive? && Time.now - t < TIMEOUT
            Thread.pass
           end
       }
     rescue Exception
     end 
     if obj.alive?
       defer[obj] = Defer.new(value.info, value.count + 1, value.handler, value.session_id)
     else
       Intepreter.call(obj.value, value.info, value.handler, run, defer, value.session_id) if obj.value
     end
  }
     
  def self.on_general(type, *args)
    case type
    when "private"
      on_group args[0], args[1], -args[2], args[2], args[3], args[4]
    end
  end

  def self.on_idle
    begin
        ret = []
           
        newdef = {}
        DEFERED.each{|k, v|
          begin
            DeferedRunner.call(k, ret, newdef, v)
          rescue Exception
            STDERR.puts $!.backtrace.unshift($!.to_s).join("\n")
		        ret << $!.backtrace.unshift($!.to_s).join("\n")
          end
        }
        DEFERED.clear
        DEFERED.update(newdef)

        ret
    rescue Exception
        return $!.backtrace.unshift($!.to_s).join("\n").encode('gbk', 'utf-8', replace: '?')
    end
  end
  
  #def self.on_group(subtype, sendtime, fromGroup, fromQQ, anonymous, msg, font)
  def self.on_group(*args)
    return if  !GROUP.include?(args[2]) && !Privilege.user_has_privilege(args[2], 'grouptalk') 
    return if  Privilege.user_has_privilege(args[3], 'ban')
    self.current = args
    msg = CGI.unescapeHTML((args[-2].force_encoding("GBK")).encode("UTF-8"))
    fromQQ = args[3]
    fromGroup = args[2]
    case msg 
      when /\A:(\S+)\s+([\w\W]*)\Z/, /\A:(\S+)\s*/
        name, arg = $1, ($2 || "")
        priv_id = Privilege.find_priv_id(name)
        if !priv_id
           return "Error 101: no such special command #{name}".encode('gbk', 'utf-8', replace: '?')
        end
        unless Privilege.find_user_all_priv(fromQQ).include?(priv_id)
          return  "Error 100: can't run #{$1} from #{fromQQ}, user/group not allowed".encode('gbk', 'utf-8', replace: '?')
        end
        begin
          require "lib/commands/#{name}.rb"
        rescue LoadError
          return "Error 101: no such special command #{name}".encode('gbk', 'utf-8', replace: '?')
        end
	      begin
          return OpenRobot::Command.send("do_#{name}", arg).encode('gbk', 'utf-8', replace: '?')
        rescue Exception
         # return "Error 102: can't execute #{name}"
	        return $!.backtrace.unshift($!.to_s).join("\n").encode('gbk', 'utf-8', replace: '?')
        end
      else
      begin
        ret = []
           
        newdef = {}
        DEFERED.each{|k, v|
          begin
            DeferedRunner.call(k, ret, newdef, v)
          rescue Exception
            STDERR.puts $!.backtrace.unshift($!.to_s).join("\n")
		        ret << $!.backtrace.unshift($!.to_s).join("\n")
          end
        }
        DEFERED.clear
        DEFERED.update(newdef)

         pair = [args[2], args[3]]
         allmember = [args[2], :all]
         SESSIONS.each{|id, session|
            if session && session.clients && (session.clients.include?(pair) || (args[2] > 0 && session.clients.include?(allmember)))
               begin
                session.mutex.synchronize{
                   Runner.call(session.handler, {message: msg, match: nil, qq: args[3], all: OpenRobot.current, store: session.store}, ret, DEFERED, id)
                }
               rescue Exception
                     STDERR.puts $!.backtrace.unshift($!.to_s).join("\n")
		                 ret << $!.backtrace.unshift($!.to_s).join("\n")
               end
            end
         }
         SESSIONS.delete_if{|id, session|
            !session || !session.store || session.store.env == nil 
         }

        PROCS.each{|k, v|
          begin
             if k === msg
               v.each{|z|
                 begin
                     Runner.call(z, {message: msg, match: $~, qq: args[3], all: OpenRobot.current, store: nil}, ret, DEFERED, nil)
                 rescue Exception
                     STDERR.puts $!.backtrace.unshift($!.to_s).join("\n")
		                 ret << $!.backtrace.unshift($!.to_s).join("\n")
                 end
               }
             end
          rescue Exception
                     STDERR.puts $!.backtrace.unshift($!.to_s).join("\n")
		                 ret << $!.backtrace.unshift($!.to_s).join("\n")
          end
        }
     
     
        ret
       rescue Exception
         # return "Error 102: can't execute #{name}"
	        return $!.backtrace.unshift($!.to_s).join("\n").encode('gbk', 'utf-8', replace: '?')
        end
    end
  
  end

  
  def self.register(cond, lb = nil, &bl)
    PROCS[cond] ||= []
    PROCS[cond] << (lb || bl)
  end

  def self.unregister(cond, lb = nil, &bl)
    PROCS[cond] ||= []
    PROCS[cond].delete (lb || bl)
  end


  def self.on_error(*args)
    puts $!.backtrace.unshift($!.to_s)
    STDOUT.flush
  end
end