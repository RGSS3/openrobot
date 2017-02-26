require 'timeout'
module OpenRobot
  class << self
    attr_accessor :current
  end
  
  Store   = Struct.new :message, :env 
  Direct  = Struct.new :group_id, :message
  Defer   = Struct.new :info, :count, :handler
  Session = Struct.new :store, :handler
  
  PROCS    = {}
  DEFERED  = {}
  SESSIONS = {}
  NEXTSESSIONS = {}
  TIMEOUT  = 1
  #todo 

  Intepreter = lambda{|value, info, handler, run, defer|
      case
      when String === value
        state = [info[:all][2], info[:all][3]]
        NEXTSESSIONS[state] ||= {}
        NEXTSESSIONS[state].delete handler
        run << [info[:all][2], value.encode('gbk')]
      when Store === value
        Intepreter.call(value.message, info, handler, run, defer)
        state = [info[:all][2], info[:all][3]]
        NEXTSESSIONS[state] ||= {}
        NEXTSESSIONS[state][handler] = value
      end
  }
  
  
  Runner = lambda{|handler, info, run, defer|
     begin  
       u = Thread.new { 
           begin
             handler.call(info)
           rescue Exception 
             nil
           end}
       u.abort_on_exception = true
       Timeout::timeout(TIMEOUT){
           t = Time.now
           while u.alive? && Time.now - t < TIMEOUT
             Thread.pass
           end
       }
     rescue Exception
     end 
    
     if u && u.alive?
       defer[u] = Defer.new info, 1, handler
     else
       Intepreter.call(u.value, info, handler, run, defer) if u.value
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
       defer[obj] = Defer.new(value.info, value.count + 1, value.handler)
     else
       Intepreter.call(obj.value, value.info, value.handler, run, defer) if obj.value
     end
  }
     
  
  #def self.on_group(subtype, sendtime, fromGroup, fromQQ, anonymous, msg, font)
  def self.on_group(*args)
    return if  !GROUP.include?(args[2])
    self.current = args
    msg = CGI.unescapeHTML((args[-2].force_encoding("GBK")).encode("UTF-8"))
    fromQQ = args[3]
    case msg 
      when /\A:(\S+)\s+([\w\W]*)\Z/, /\A:(\S+)\s*/
        name, arg = $1, ($2 || "")
        priv_id = Privilege.find_priv_id(name)
        if !priv_id
           return "Error 101: no such special command #{name}".encode('gbk', 'utf-8')
        end
        unless Privilege.find_user_all_priv(fromQQ).include?(priv_id)
          return "Error 100: can't run #{$1} from #{fromQQ}, user/group not allowed".encode('gbk', 'utf-8')
        end
        begin
          require "lib/commands/#{name}.rb"
        rescue LoadError
          return "Error 101: no such special command #{name}".encode('gbk', 'utf-8')
        end
	  begin
          OpenRobot::Command.send("do_#{name}", arg).encode('gbk', 'utf-8')
        rescue Exception
         # return "Error 102: can't execute #{name}"
	        return $!.backtrace.unshift($!.to_s).join("\n").encode('gbk', 'utf-8')
        end
      else
        ret = []
           
        newdef = {}
        DEFERED.each{|k, v|
          begin
           DeferedRunner.call(k, ret, newdef, v)
          rescue Exception
            puts $!.backtrace.unshift($!.to_s).join("\n")
          end
        }
        DEFERED.clear
        DEFERED.update(newdef)

        pair = [args[2], args[3]]
        STDERR.puts SESSIONS.inspect
        if SESSIONS[pair]
         begin
          SESSIONS[pair].each{|handler, store|
                STDERR.puts [handler, store].inspect
                Runner.call(handler, {message: msg, match: nil, qq: args[3], all: OpenRobot.current, store: store}, ret, DEFERED)            
          }
          
          rescue Exception
                STDERR.puts $!.backtrace.unshift($!.to_s).join("\n")
            end
        end
        
        PROCS.each{|k, v|
          begin
             if k === msg
               v.each{|z|
                 begin
                     Runner.call(z, {message: msg, match: $~, qq: args[3], all: OpenRobot.current, store: nil}, ret, DEFERED)
                 rescue Exception
                     STDERR.puts $!.backtrace.unshift($!.to_s).join("\n")
		                 #ret << $!.backtrace.unshift($!.to_s).join("\n")
                 end
               }
             end
          rescue Exception
                     STDERR.puts $!.backtrace.unshift($!.to_s).join("\n")
		                 #ret << $!.backtrace.unshift($!.to_s).join("\n")
          end
        }
     
        SESSIONS[pair] = NEXTSESSIONS[pair]
        NEXTSESSIONS.delete pair if NEXTSESSIONS[pair]
        ret
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