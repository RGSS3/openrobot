O   = OpenRobot
OC  = O::Command
OCR = O::Command::Request
P   = Privilege
PE  = P::Entity
PR  = P::Relation

Store  = O::Store
def S(*args)
  O::Store.new(*args)
end

def D(&block)
  t = Thread.new(&block)
  t.abort_on_exception=true
  O::DeferedValue.new(t)
end

def R(*args, &block)
  OpenRobot.register *args, &block
end

def F(*args, **kw, &block)
  Tempfile.new(*args, **kw, &block)
end

def join_same_group(qq)
  OpenRobot::JoinSession.new [OpenRobot::current[2], qq]
end

def join_all
  join_same_group(:all)
end

class SessionHelper
   attr_accessor :data
   attr_accessor :events
   attr_accessor :msg, :qq, :group, :match, :info, :all
   def template(a, env = {})
     a.gsub(/\{\{([^}]+)\}\}/){env[$1.to_sym]}
   end
   def initialize(name, init, initmsg = "{{qq}} 开始了 #{name}", &block)
     @initmsg  = initmsg
     @init = init
     @name = name
     @step_proc = block
   end

   def call(info)
     if !info[:store]
        S template(@initmsg, info), @init
     elsif info[:message] =~ /^-add/
        if info[:message]["all"]
          [join_all, S("#{info[:qq]}已将全员加入#{@name}", info[:store].env)]
        else
          r = info[:message].scan(/\d+/).to_a.map(&:to_i)
          j = r.map{|x| join_same_group(x)}
          s = r.join(", ")
          [*j, S("#{info[:qq]}已将#{s}加入#{@name}", info[:store].env)]
        end
     else
       self.data = info[:store].env
       self.msg  = info[:message]
       self.qq   = info[:qq]
       self.match = info[:match]
       self.group = info[:all][2]
       self.all   = info[:all]
       self.info  = info
       msg       = instance_exec &@step_proc
       S msg, self.data
     end
    rescue Exception
      $!.backtrace.unshift($!.to_s).join("\n")
    end

    def end_session msg
      self.data = nil
      msg
    end 

    def continue(&block)
      self.data = yield self.data
    end
end

def RSH pattern, name, init, msg = nil, &block
   R pattern, SessionHelper.new(name, init, msg || "{{qq}} 开始了 #{name}", &block)
end

def TempImage(a, b)
  Tempfile.open(["image-", ".png"], "data/image/tmp", mode: File::BINARY) do |f|
    img = Image.new(a, b)
    yield img
    f.close
    img.write "png:#{f.path}"
    "[CQ:image,file=tmp/#{File.basename(f.path)}]"
  end
end

