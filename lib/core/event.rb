require 'timeout'
module OpenRobot
  class << self
    attr_accessor :current
  end
  PROCS   = {}
  DEFERED = {}
  
  #todo 
  Runner = lambda{|handler, info, run, defer|
     u = Thread.new { handler.call(info).encode('gbk', 'utf-8') }
     begin  
       Timeout::timeout(0.1){
           t = Time.now
           while u.alive? && Time.now - t < 0.1
             Thread.pass
           end
       }
     rescue Exception
     end 
    
     if u.alive?
       defer[u] = {info: info, value: 1}
     else
       run << [info[:all][2], u.value]
     end
  }

  DeferedRunner = lambda{|obj, run, defer, value| 
      begin  
       Timeout::timeout(0.1){
           t = Time.now
           while obj.alive? && Time.now - t < 0.1
            Thread.pass
           end
       }
     rescue Exception
     end 
     if obj.alive?
       defer[obj] = {info: value[:info], value: value[:value] + 1}
     else
       run << [value[:info][:all][2], obj.value]
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

        PROCS.each{|k, v|
          begin
             if k === msg
               v.each{|z|
                 begin
                   Runner.call(z, {message: msg, match: $~, qq: args[3], all: OpenRobot.current}, ret, DEFERED)
                 rescue Exception
		                # ret << $!.backtrace.unshift($!.to_s).join("\n")
                 end
               }
             end
          rescue Exception
            #ret << $!.backtrace.unshift($!.to_s).join("\n")
          end
        }
     
        
        p ret
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