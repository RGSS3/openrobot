O   = OpenRobot
OC  = O::Command
OCR = O::Command::Request
P   = Privilege
PE  = P::Entity
PR  = P::Relation
require 'net/http'
require 'openssl'
Store  = O::Store
def S(*args)
  O::Store.new(*args)
end





def GET(uri, host = nil, port = nil)
  url = URI(uri)
  r = URI(ENV['HTTP_PROXY']|| "")
  host ||= r.host
  port ||= r.port
  Net::HTTP.start(url.host, url.port, host, port, use_ssl: url.scheme == "https", verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
   request = Net::HTTP::Get.new(url.request_uri)
   response = http.request(request)
   response.body
 end
rescue
  nil
end

alias HTTP GET
alias HTTPS GET

def POST(uri, data = {}, host = nil, port = nil)
  url = URI(uri)
  r = URI(ENV['HTTP_PROXY'] || "")
  host ||= r.host
  port ||= r.port
  Net::HTTP.start(url.host, url.port, host, port, use_ssl: url.scheme == "https", verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
   request = Net::HTTP::Post.new(url.request_uri)
   request.body = data
   response = http.request(request)
   response.body
 end
rescue
  nil
end


def PM(*a)
  O::PrivateMessage.new *a
end


def HTTP(uri, *a)
   url = URI(uri)
   Net::HTTP.start(url.host, url.port, *a) do |http|
    request = Net::HTTP::Get.new(url.request_uri)
    response = http.request(request)
    response.body
  end
end

def HTTPPost(uri, data, *a)
  url = URI(uri)
  Net::HTTP.start(url.host, url.port, *a) do |http|
   request = Net::HTTP::Post.new(url.request_uri)
   request.body = data
   response = http.request(request)
   response.body
 end
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

def RES(n)
  Resource::Resource.new(n)
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



class SessionHelper2
   class Runner 
      attr_accessor :data, :info, :fib, :block
      def initialize(&block)
          self.block = block
          self.fib   = Fiber.new{ instance_exec &self.block }
      end

      def call(info)
          self.info = OpenStruct.new(info)
          self.fib.resume info[:message]
      end

      def send! *args
        Fiber.yield *args
      end
   end


   def initialize(&block)
     @block = block
   end

   def call(info)   
     if !info[:store] || !info[:store].env
       f = Runner.new(&@block)
       u = f.call(info)
       S u, f
     else
       f = info[:store].env
       u = f.call(info)
       S u, (!f.data ? nil : f)
     end
   rescue Exception
      $!.backtrace.unshift($!.to_s).join("\n")
   end
end

SH2 = SessionHelper2

class SessionHelper3
  class Runner
    attr_accessor :states, :data, :info
    def state(name, lb = nil, &bl)
      states[name] = lb || bl
    end

    def initialize(&block)
      @states = {}
      @states [
        :finish
      ] = lambda{|*|
       self.data = nil
      }
      @states [
        :init 
      ] = lambda{|*|
         transit :finish, nil
      }
      instance_exec &block
      @current = :init
    end

    def call(info)
      self.info = OpenStruct === info ? info : OpenStruct.new(info)
      instance_exec info[:message], &states[@current]
    end

    def transit(nextstate, ret)
      @current = nextstate
      ret
    end

  end

   def initialize(&block)
     @block = block 
   end
 
   def call(info)   
     if !info[:store] || !info[:store].env
       f = Runner.new(&@block)
       u = f.call(info)
       S u, f
     else
       f = info[:store].env
       u = f.call(info)
       S u, (!f.data ? nil : f)
     end
   rescue Exception
      $!.backtrace.unshift($!.to_s).join("\n")
   end

end

SH3 = SessionHelper3

def RSH pattern, name, init, msg = nil, &block
   R pattern, SessionHelper.new(name, init, msg || "{{qq}} 开始了 #{name}", &block)
end

def TempImage(*a)
  Tempfile.open(["image-", ".png"], "data/image/tmp", mode: File::BINARY) do |f|
    img = Image.new(*a)
    yield img
    f.close
    img.write "png:#{f.path}"
    "[CQ:image,file=tmp/#{File.basename(f.path)}]"
  end
end

def TempImageData(*data)
  Tempfile.open(["image-", ".png"], "data/image/tmp", mode: File::BINARY) do |f|
    yield f
    f.close
    "[CQ:image,file=tmp/#{File.basename(f.path)}]"
  end
end

class RunDocker
  IMAGE = {"php" => "php", "ghc" => "mitchty/alpine-ghc"}
  def run(lang, cmdline,  opt = {}) 
    Dir.mktmpdir("run", "tmp") do |dir|
    begin
      tmpname = File.basename(dir)
      image   = IMAGE[lang] || "ruby"
      IO.binwrite "#{dir}/Dockerfile", %{
FROM #{image}
#{
  opt.map do |k, v|
    "ADD #{k} ~/#{k}"
  end.join("\n")
}
CMD [#{cmdline.inspect}]
}.delete("\r")
      opt.each{|k, v|
        IO.binwrite "#{dir}/#{k}", v
      }
      IO.write "#{dir}/run.cmd", "
@docker build -t #{tmpname}:0.01 tmp/#{tmpname} --force-rm 1>nul 2>&1
@docker run --rm -a stdin -a stdout -a stderr -i -t #{tmpname}:0.01
@docker rmi -f #{tmpname}:0.01 > nul
"

      ret = `#{dir}\\run.cmd`
      Dir.glob("#{dir}/*") do |f| File.delete f end 
      ret.chomp("\n")
       
    end
    end
  end
end

class Res
  def initialize(desc, &block)
    @desc = desc
    @block = block
  end

  def get
    case @desc
    when /^https/
       HTTPS @desc
    when /^http/
       HTTP @desc
    when :ximg
       TempImageData(&block)
    when :html
       #
    else
       raise
    end
  end

  
end

def DIS(hash)
  u = hash.values.inject(:+)
  val = rand(u)
  hash.each{|k, v|
    return k if val < v
    val -= v
  }
end

class LSReference
  def initialize(*args)
    @path = args
    if !LocalStorage.get('ref', @path)
      LocalStorage.set('ref', @path, {})
    end
  end
  def set(a, b)
    LocalStorage.set('ref', @path + [a], b)
  end
  def get(a)
    LocalStorage.get('ref', @path + [a])
  end
  alias []  get
  alias []= set
end

def LSREF(key, lb = nil, &bl)
  r = lb || bl
  lambda{|info|
    info[:ls] = LSReference.new(info[:group], info[:qq], key)
    r.call(info)
  }
end

class WebSession
  def initialize(uri)
    @uri = URI uri
  end
  def call(info)
    u = info.merge(store: info[:store] && info[:store].to_h)
    ret = JSON.parse(POST(@uri, JSON.dump(u)))
    if ret["env"]
      S ret["message"], ret["env"]
    else
      ret["message"]
    end
  rescue
    S "连接异常，请重试", info[:store] && info[:store].env
  end
end