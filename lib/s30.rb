=begin
  This is only a very alpha version of Seiran30, 
    only ? of 30 features are included
    do not redistribute 
  Author: Seiran
=end

module Seiran30 
  extend self
  #
  # 1 / 30, scope related stuff
  #
	
  #
  #  this method will use class_eval as long as possible, use instance_eval as fallback
  #
  def special_eval(*a, &b)
     respond_to?(:class_eval) ?  class_eval(*a, &b) :is_main? ? ::Object.class_eval(*a, &b) : instance_eval(*a, &b)
  end
  
  def is_main?
     eval('self', TOPLEVEL_BINDING) == self
  end

  def special_class
     respond_to?(:class_eval) ?  self : is_main? ? ::Object : (class << self; self; end)
  end
  
  
  def special_def(a, &b)
     special_class.class_eval { define_method(a, &b) }
     instance_eval{ define_method(a, &b) }
  end
  
  def special_instance
    class << self; self; end
  end

  a = Module.new.class_eval { lambda{42} }
  begin
	instance_eval(&a)
	alias instance_eval0 instance_eval
  rescue ArgumentError
	def instance_eval0(&block)
		instance_exec &block
	end
  end
  
 
  def special_singleton
     class << self; self; end
  end
  
  def special_def(name, &bl)
	special_class.class_eval{
		define_method(name, &bl)
	}
	special_instance.class_eval{
		define_method(name, &bl)
	}
  end

  def special_constset(name, value)
	special_class.send :const_set, name, value  
  end

  def special_define_singleton_method(name, &bl)
	special_singleton.class_eval{
		define_method(name, &bl)
	}
  end

   def raise_with_class(*a)
       raise *a
   rescue Exception
       raise $!.class, self.class.to_s + " : " + $!.message, $!.backtrace
   end
  

  def s30set(a, b)
      @__s30_storage ||= {}
      @__s30_storage[a] = b
  end
  
  def s30get(a)
      @__s30_storage ||= {}
      @__s30_storage[a]
  end
  
  class StaticClass
	  attr_accessor :self
	  def initialize(obj)
		  @self = obj
	  end
	  def self.method_missing sym, &bl
		define_method sym, bl
	  end
  end
  
  def static_define_method(name, lb = nil, &bl)
	doit = lb || bl
	m = Class.new(StaticClass)
	m.class_eval &doit
	special_class.class_eval{
		define_method(name) do |*args|
			m.new(self).call(*args)
		end
	}
  end
  
  
  # wrapper of s30get/set
  class S30Storage
	def initialize(obj)
		@obj = obj
	end
	def []=(*a)
		@obj.s30set(*a)
	end
	def [](*a)
		@obj.s30get(*a)
	end
  end

  # wrapper of s30get/set 
  def s30local
        S30Storage.new(self)
  end
  
  def s30global
	S30Storage.new(Seiran30)
  end
  
  class << self
	attr_accessor :scope_stack
  end
  
  self.scope_stack = []
  
  #
  # ge t global scope stack
  #
  def s30scopestack
	Seiran30.scope_stack  
  end

  #
  # get current scope 
  #
  def s30scope
	Seiran30.scope_stack.last
end

  def toplevel_self
	  eval 'self', TOPLEVEL_BINDING
  end
  
   module Procs
	ID       = lambda{|a| a }
   end


   if !defined?(Mutex) && Thread.respond_to?(:critical) 
	class Mutex
		def initialize
			@lockthread = nil
		end
		
		def _lockthread
			Thread.critical = true
			a = @lockthread
			if a && !a.alive?
				@lockthread = nil
			else
				a
			end
		ensure
			Thread.critical = false
		end
		
		def _lockthread=(rhs)
			Thread.critical = true
			@lockthread = rhs
		ensure
			Thread.critical = false
		end
		
		def locked?
			!!_lockthread
		end
		
		def lock
			raise ThreadError, "deadlock; recursive locking" if _lockthread == Thread.current
			1 while locked?
			self._lockthread = Thread.current
			self
		end
		
		def try_lock
			if _lockthread == nil
				self._lockthread = Thread.current
				true
			else
				false
			end
		end
		
		def unlock
			raise ThreadError, "Attempt to unlock a mutex which is not locked" if _lockthread == nil
			raise ThreadError, "Attempt to unlock a mutex which is locked by another thread" if _lockthread != Thread.current
			self.lockthread = nil
			self
		end
	end
end

  if defined?(Mutex) && !(Mutex.instance_method(:synchronize) rescue nil)
	const_get(:Mutex).class_eval do
		def synchronize
		  self.lock
		  begin
			yield
		  ensure
			self.unlock rescue nil
		   end
		end
       end 
  end

  if Thread.respond_to?(:critical) 
	def exclusive
		Thread.critical = true
		yield
	ensure
		Thread.critical = false
	end
  elsif Thread.respond_to?(:exclusive) 
	def exclusive(&block)
		Thread.exclusive(&block)
	end
  elsif defined?(Mutex)
	MutexForExclusive = Mutex.new
	def exclusive(&block)
		MutexForExclusive.synchronize &block
	end
  else
	  warn "No Thread critical found"
  end
  
  class MutexQueue
	def initialize
		@arr     = []
		@mutex = Mutex.new
	end
	[:push, :pop, :concat, :shift, :unshift, :[], :[]=, :delete, :delete_at, :empty?].each{|name|
		define_method name do |*args|
			@mutex.synchronize do
				@arr.send(name, *args)
			end
		end
	}
  end
  
  class << self; attr_accessor :gen_id; end
  self.gen_id = [0]
  def gen_id(prefix = "_", gen = Seiran30.gen_id)
	gen[0] += 1
	"#{prefix}#{"%032x" % gen[0]}"
  end
  TASKS = {}
  def task(timeout = 0, &block)
	name = gen_id 
	a = {}
	a[:timeout] = timeout
	a[:block]    = block
	a[:queue]   = MutexQueue.new
	a[:thread]  = Thread.new(a) do |a|
		ret = nil
		loop do
			a[:block].call a[:queue].shift
			case a[:control]
				when :break
					break
				when :throw
					throw *a[:control_args]
				when :raise
					raise *a[:control_args]
				when :return
					ret = a[:control_args]
					break
			end
			sleep a[:timeout]
		end
		ret
	end
	a[:thread].abort_on_exception = true
	TASKS[name] = a
	Task.new(name)
   end
   class Task
	TaskError = Class.new Exception
	def initialize(name)
		@name = name
	end
	def mail(arg)
		TASKS[@name][:queue].push arg
	end
	def break
		TASKS[@name][:control] = :break
	end
	def throw(*a)
		TASKS[@name][:control_args] = a
		TASKS[@name][:control] = :throw
	end	
	def raise(*a)
		TASKS[@name][:control_args] = a
		TASKS[@name][:control] = :raise
	end	
	def return(arg)
		TASKS[@name][:control_args] = arg
		TASKS[@name][:control] = :return
	end
	def wait(timeout)
		t = Time.now
		thr =  TASKS[@name][:thread]
		while Time.now - t <= timeout && thr.alive?
			Thread.pass
		end
		thr.alive?
	end
	def value
		thr =  TASKS[@name][:thread]
		raise TaskError, "Task is still running" if thr.alive?
		thr.value
	end
	def value!
		1 until wait 0.1 
		thr.value
	end
end

  TimeoutError = Class.new Exception
  
  def timeout(timeout = nil, exception = nil)
	return yield(timeout) if timeout == 0 or timeout == nil
	exception ||= TimeoutError
	begin
		x = Thread.current
		y = Thread.new do
			begin
				sleep timeout
			rescue => ex
				x.raise ex
			else
				x.raise exception, "execution expired"
			end
		end
		yield(timeout)
	ensure
		if y
			y.kill
			y.join
		end
	end
  end
	
  def timeexpire(time_to_expire = nil, exception = nil, &bl)
	timeout time_to_expire - Time.now, exception, &bl
  end
  	

  class Ref
	attr_accessor :getter, :setter, :invoker, :storage
	def initialize(getter = nil, setter = nil, invoker = nil)  
		self.getter, self.setter, self.invoker = getter, setter, invoker
	end
	
	def copying
		[:getter, :setter, :invoker, :storage]
	end
	
	def copy
		x = self.class.new
		copying.each{|i|
			x.send("#{i}=", send(i))
		}
		x
	end
	
	def value=(*vals)
		setter.call(*vals)
	end
	def value(*vals)
		getter.call(*vals)
	end
	def call(*args)
		invoker.call(*args)
	end
	
	def critical_value=(*vals)
		exclusive do setter.call(*vals) end
	end
	
	def critical_value(*vals)
		exclusive do getter.call(*vals) end
	end
	
	def op
		self.value = yield self.value
	end
	
	alias []   value
	alias []= value=
	
	def self.global(name)
		realname = name[/\A\$[A-Za-z0-9][A-Za-z0-9_]*\Z/]
		if realname
			set = "#{realname} = ObjectSpace._id2ref "
			getter = lambda{ eval (realname) }
			setter = lambda{|val| eval(set + val.object_id.to_s)}
			new getter, setter
		end
	end
	
	def self.attr(obj, name)
		getter = lambda{ obj.send(name) }
		setter = lambda{|*val| obj.send("#{name}=", *val) }
		new getter, setter
	end
	
	def self.local(binding, name)
		realname = name.to_s
		set = "#{realname} = ObjectSpace._id2ref "
		getter = lambda{ eval(realname, binding) }
		setter = lambda{|val| eval(set + val.object_id.to_s, binding) }
		new getter, setter
	end
   end

   class PlusRef < Ref
	attr_accessor :adder, :reverse_add, :reftype, :coerce_adder
	def copying
		super + [:adder, :reverse_add, :reftype, :coerce_adder]
	end
	
	def +(rhs)
		if PlusRef === rhs && rhs.reftype == self.reftype
			adder.call(self, rhs)
		else
			coerce_adder.call(self, rhs)
		end
	end
	
	def +@
		x = copy
		x.reverse_add = true
		x
	end
	
	def value=(rhs)
		if reverse_add
			self.value = rhs + self
		else
			super
		end
	end
	
	def self.imethod(klass, name)
		getter = lambda{ klass.instance_method(name) }
		setter = lambda{|val|  klass.send(:define_method, name) do |*args| val.bind(self).call(*args) end }
		adder =  lambda{|lhs, rhs| 
			l,r  = lhs.value, rhs.value
			newname = klass.instance_methods.join("").gsub(/[^A-Za-z0-9]/, "") + "___"
			klass.send(:define_method, newname) do |*args|
				l.bind(self).call(*args)
				r.bind(self).call(*args)
			end
			PlusRef.imethod klass, newname
		}
		coerce_adder = lambda{|lhs, rhs|
			l,r = lhs.value, rhs
			ret = nil
			exclusive do
				newname = klass.instance_methods.join("").gsub(/[^A-Za-z0-9]/, "") + "___"
				klass.send(:define_method, newname, &rhs)
				ret = adder.call(lhs, imethod(klass, newname))
				klass.send(:remove_method, newname)
			end
			ret
		}
		x = PlusRef.new
		x.getter = getter
		x.setter = setter
		x.adder  = adder
		x.coerce_adder = coerce_adder
		x
	end
   end
  
=begin  
enters scope,  globally.
scope is an extended form of code blocks.
for enter_scope with a block, these scope options are used:
[:rescues]
    an array like [StandardError, Errno::ENOENT]. enter_scope may call with a block:
      enter_scope scope do
          ...
	end
    


    is the almost same as
      enter_scope scope
          ...
	leave_scope
    
but :rescues field will be used to automatically catch exceptions in the block
[:middles]
  an array like [a, b, c]. it means the block in enter_scope is evaluated as 
         compound function of a . b . c . block
[:args]
   arguments passed to the block

   
example:
    include Seiran30
    x = Bitmap.new "Graphics/Battlers/Angel"
    y = Sprite.new
    y.bitmap = x
    loop = lambda{|b, *a| b.call until false }
    enter_scope :update => [Graphics, Input, y], :middles => [loop] do
	  update_scope
    end
    
there is some settings for s30local[:__scope_special_func__]
[:update] 
    a hash like :update1 => :update2. It means update_scope will invoke: scope[ :update1 ].each(&:update2)
                            default :update => :update
[:leave]
   same as above. For :dispose1 => :dispose2, it means leave_scope will invoke: scope[ :dispose1 ].each(&:dispose2)
			default :dispose => :dispose
   

=end   
  def enter_scope(scope = {}, &bl)
	s30local[:__scope_special_func__] ||={}
	s30local[:__scope_special_func__] = {
	  :update  => {:update => :update},
	  :leave    => {:dispose => :dispose},
	  
	}.merge(s30local[:__scope_special_func__] )
	scope[:update] ||= []
	scope[:dispose] ||= []
	scope[:middles] ||= []
	scope[:rescues] ||= [StandardError]
	scope[:args] ||= {}
	r = s30local[:__scope_special_func__][:rescues]
	s30scopestack.push scope
	
	begin
		args = scope[:args]
		result = scope[:middles].reverse.inject(lambda{|*args|bl.call(*args)}){|a, b|
			lambda{|*args| b.call(a, *args)}
		}
		scope[:ret] = result.call(*args)
	rescue *r
		scope[:__exception] = $!
		scope
	ensure
		leave_scope
	end if block_given?
end

  alias push_scope enter_scope
  #
  # leaves a scope, globally, special function *leave* is related
  # see enter_scope
  #
  def leave_scope
	lastscope = s30scopestack.pop
	if settings = s30local[:__scope_special_func__]
	   if leave = settings[:leave]
	      leave.each{|k, v|
	         lastscope[k].each{|x| x.send(v)}
	      }
	   end
       end
       lastscope
  end
  
  #
  #updates a scope,  globally, special function *update* is related
  #see enter_scope
  #
  def update_scope
	lastscope = s30scope
	if settings = s30local[:__scope_special_func__]
	   if leave = settings[:update]
	      leave.each{|k, v|
	         lastscope[k].each{|x| x.send(v)}
	      }
	   end
       end
       lastscope
  end
  
  
  #
  # 2 / 30, api basic releated stuff
  #
  
  #
  #  Handles to normal API call
  #
  class API
     attr_accessor :dll, :func, :aliasname
     def initialize(dll, func, aliasname = func)
	self.dll, self.func, self.aliasname = dll, func, aliasname
     end

     def self.pack(args)
	args.map{|x| 
	  case x
		  when Integer then x
		  when Float  then [x].pack("F").unpack("L").first
		  when String then [x].pack("p").unpack("L").first
		  else x.to_int
	  end
	}
     end
     #
     # call API using given arguments
     #
    def call(*args)
	u = self.class.pack(args)
	(@api ||= Win32API.new(dll, func, "L"*args.length, "l")).call(*u)
    end

    def callp(*args)
	u = self.class.pack(args)
	(@apip ||= Win32API.new(dll, func, "L"*args.length, "p")).call(*u)
    end

    def address
	Seiran30.funcaddr dll, func
    end

    def as_addr
	memory(address)
    end

    def to_promise(*args)
	promise(as_addr.threadcall(*args))
    end

    def async
	method(:to_promise)
    end

  end
  
=begin
  define api with given DLL's name and function name
  example1:
  
       include Seiran30
       defapi 'user32', 'MessageBox'
       MessageBox 0, "Hello", 0, 16
  example2:
  
       include Seiran30
       defapi 'user32', 'MessageBoxA', 'MessageBox'
       MessageBox 0, "Hello", 0, 16
  
  example3:
        include Seiran30
        defapi('user32', 'MessageBoxA').call(0, "Hello", 0, 16)
=end  

  def defapi(dll, func, name = func)
      s30local[:__api] ||= {}
      fullname = "#{dll}.#{func}"
      that = s30local[:__api]
      s30local[:__api][fullname] ||= begin
         ret = API.new(dll, func, name) 
         special_def name do |*args|
	       that[fullname].call(*args)
         end	
	 special_class.class_eval { private name } unless s30local[:public]
         ret
      end
  end
  
  def declapi(dll, *funcs)
	  funcs.each{|func| defapi(dll,func)}
  end
  
  def defapi_async(dll, func, name = func)
      s30local[:__api] ||= {}
      fullname = "#{dll}.#{func}"
      that = s30local[:__api]
      s30local[:__api][fullname] ||= begin
         ret = API.new(dll, func, name) 
         special_def name do |*args|
	       that[fullname].async.call(*args)
         end	
	 special_class.class_eval { private name } unless s30local[:public]
         ret
      end
  end
  
  def declapi_async(dll, *funcs)
	  funcs.each{|func| defapi_async(dll,func)}
  end
  
  module Kernel32
      extend Seiran30
      extend self
      %w[
        LoadLibraryW
        GetModuleHandle
        GetProcAddress
        MultiByteToWideChar
        WideCharToMultiByte
        RtlMoveMemory
	GlobalAlloc
	GlobalFree
      ].each{|x|
        defapi "Kernel32", x
        public x
     }
     
     def self.method_missing(sym, *args)
	defapi "Kernel32", sym
	send sym, *args
     end
  end
  
  module User32
      extend Seiran30
      extend self
      %w[
        MessageBoxA
	MessageBoxW
      ].each{|x|
        defapi "User32", x
        public x
     }
     def self.method_missing(sym, *args)
	defapi "User32", sym
	send sym, *args
     end
  end
  
  # multi-byte string to wide-char string 
  def strencode(str, from = 65001)
      str << "\0" if String === str # ensure ended by null char
      len = Kernel32.MultiByteToWideChar(from, 0, str, -1, 0, 0)
      out = "\0\0" * (len + 1)
      Kernel32.MultiByteToWideChar(from, 0, str, -1, out, out.length)
      out[0, len * 2]
  end
  
  # wide-char string to multi-byte string
  def strdecode(str, to = 65001)
      str << "\0\0" if String === str # ensure ended by null wchar
      len = Kernel32.WideCharToMultiByte(to,  0, str, -1, 0, 0, 0, 0)
      out = "\0" * (len + 1)
      Kernel32.WideCharToMultiByte(to, 0, str, -1, out, out.length, 0, 0)
      out[0, len]
  end

  CODEPAGE = {:utf8 => 65001, :oem => 0, :ansi => 0, :gbk => 936, :unicode => -1}
  def iconv(from = 65001, to = 0)
	unless Integer === from
	   from  = from.to_s.downcase.tr("-", "").to_sym
	   from = CODEPAGE[from]
        end
        unless Integer === to
	   to    = to.to_s.downcase.tr("-", "").to_sym
	   to    = CODEPAGE[to]
	end
	lambda{|str| strdecode(strencode(str, from), to) }
  end

  def funcaddr(a, b)
	lib = Kernel32.LoadLibraryW(strencode(a))
	lib = lib == 0 ? Kernel32.GetModuleHandle(strencode(a)) : lib
	Kernel32.GetProcAddress(lib, b)
  end
   
 # 2.1 API Helper
 module APIHelper
     FORMAT_VB6_CONST = {
        :format => /Const (?<name>\S+) = (?<value>[^\n']+)/, 
   	    :read => lambda{|match, add, hash| 
        value = match["value"]
	case
	when value=~/^&H([[:xdigit:]]+)/ # /
		result = $1.to_i(16)
	when value=~/^([[:digit:]]+)/ # /
		result = $1.to_i
	when hash[value]
		result = hash[value]
	else
		result = value
	end
	add.call(match["name"], result)
     }}
     
     def self.apiconst(text, opt)
	hash = {}
	add = hash.method(:[]=)
	text.scan(opt[:format]) do 
		opt[:read].call($~, add, hash)
	end
	hash
    end

    FORMAT_GUID = {
	:format => /DEFINE_GUID\(([^,\s]+), ([^\)]+)\)/,
	:read =>  lambda{|match, add, hash| 
		name = match[1]
		value = match[2].split(",").map{|x|
			x.to_i(16)
		}.pack("LSSCCCCCCCC")
		add.call(name, value.inspect)
	}
    }

 end
 
 
 
 def defapiconst(text, opt = APIHelper::FORMAT_VB6_CONST)
    consts = APIHelper.apiconst(text, opt)
    str = ""
    consts.each{|k, v|
	str << "#{k} = #{v}\n"
    }
    special_class.class_eval str
 end

 module DSLBase
		def initialize(&block)
						reset
						instance_eval &block if block
		end
		def reset
		end
 end

 module BinaryGenerator
		include DSLBase
	        def reset
						@code = ""
		end

		def result
						@code
		end

		def write(str)
						@code << str
		end

		def int(*a)
						write API.pack(a).pack("L*")
		end

		def short(*a)
						write a.pack("S*")
		end

		def char(*a)
						write a.pack("C*")
		end

		
					
		alias dd int
		alias dw short
		alias db char
 end
=begin
  Limited VM

  Used to generate basic instructions

  In order to generator complex instructions, use PlusVM instead
=end
 class BaseVM 
		include BinaryGenerator
                                                                            def
                load(a);                db 0xb8
                                        dd a                            end;def
                push;                   db 0x50                         end;def
                call;                   db 0xff, 0xd0                   end;def
                end_cwp;                db 0xc9, 0xc2, 0x10, 0x00       end;def
                end_thread;             db 0xc9, 0xc2, 0x04, 0x00       end;def
                end_cdecl;              db 0xc9, 0xc3                   end;def
	        	unalloc(n);             db 0x83, 0xc4, n                end;def
                loadframe;	        	db 0x8b, 0xc5                   end;def
                inc;                    db 0x40                         end;def
                dec;                    db 0x48                         end;def
                shl;			        db 0xd1, 0xe0                   end;def
                shr;                    db 0xd1, 0xe8                   end;def
                end_stdcall(nargs);     db 0xc9, 0xc2
                                        dw nargs * 4                    end;

		def pushi(i)
					API.pack(i).each{|intval|
						db 0x68
						dd intval
					}
		end

		def function(type = nil, *a)
						db 0x55, 0x8b, 0xec
						if type
										yield
										send "end_#{type}", *a
						end
		end
 end 

 class Memory
    extend Seiran30
    defapi 'Kernel32', 'RtlMoveMemory'
    defapi 'User32', 'CallWindowProcW'
    defapi 'Kernel32', 'CreateThread'
    attr_reader :start, :storage, :len
    def initialize(start, len = nil)
	@start = start
	@len    = len
    end
    def to_int
	    start
    end
    def self.createPointer
	x = [0].pack("L")
	yield [x].pack("p").unpack("L").first
	new x.unpack("L").first
    end 
    def []=(a, b, c)
	RtlMoveMemory @start + a,  c, [c.length, b].min
	[c.length, b].min
   end
   def [](a, b)
	buf = "\0"*b
	RtlMoveMemory buf, @start + a, b
	buf
   end
   attr_accessor :cdecl
   def call(*args)
		that = self
		code = BaseVM.new do
                        function(:cwp) do
				pushi args.reverse
				load that.start
				call
				unalloc args.length if that.cdecl
			end
		end.result
		CallWindowProcW code, 0, 0, 0, 0
   end

   #
   # A class that wrappers windows threads
   # 
   class NativeThread
	attr_accessor :handle, :storage
	extend Seiran30


	# :method: WaitForMultipleObject
	#
	defapi 'Kernel32', 'WaitForSingleObject'

	# :method: GetExitCodeThread
	#
	defapi 'Kernel32', 'GetExitCodeThread'

	# :method: TerminateThread
	#
	defapi 'Kernel32', 'TerminateThread'

	#
	# implicit conversion to integer
	#
	def to_int
		handle
	end

	#
	#  Wait a thread for sometime or  wait a thread to exit
	#
	# :call-seq: 
	#   await(time)   # wait for sometime (in seconds)
	#   await()       # wait until it's done
	def await(t = nil, env = {})
		t *= 1000 if t
		t ||= -1
		ret = WaitForSingleObject handle,  t.to_i
		case ret
			when 0         then true
			when 0x102  then false
			else
				nil
		end
	end
	
	def timeout(t = nil, env = {})
		if await t, env
			value
		else
			kill
			raise TimeoutError, "execution expired"
		end
	end
	
	def timeexpire(time_to_expire = nil, env = {})
		if await time_to_expire - Time.now , env
			value
		else
			kill
			raise TimeoutError, "execution expired"
		end
	end

	#
	# Get the thread's return-value
	# 
	def value
		ret = "\0"*4
		GetExitCodeThread handle, ret
		ret.unpack("L").first
	end

	#
	# kill the thread
	#
	def kill(exitval = 0)
		TerminateThread handle, exitval
	end
	
   end

   #
   # :call-seq: threadstart(argpack) -> NativeThread
   #
   def threadstart(arg = 0, storage = nil)
      n = NativeThread.new
      n.handle = CreateThread 0, 0, @start, arg, 0, 0
      n.storage = storage
      n
   end
   def threadcall(*args)
		that = self
		code = BaseVM.new do
			function(:thread) do
				pushi args.reverse
				load that.start
				call
				unalloc args.length if that.cdecl
			end
		end.result
		memory(code).threadstart 0, code
   end

   def threadcall_timeout(t, *args)
	n = threadcall(*args)   
	n.timeout t
   end

   def threadcall_timeexpire(t, *args)
	n = threadcall(*args)   
	n.timeexpire t
   end

   def ptr(byteoffset)
		self.class.new read(byteoffset, 4).unpack("L").first
   end

   def virtualcall(index, *args)
     ptr(0).ptr(index * 4).call(@start, *args)
   end

   alias read []
   alias write []=
 end
  def memory(a = 0)
     return a if Memory === a
     a = [a].pack("p").unpack("L").first if String === a
     Memory.new(a)
  end
 
  def msgbox_timeout(name, timeout = nil)
	if !timeout
		API.new("user32", "MessageBoxW").call(0, strencode(name), strencode("Information"), 0)
	else
		begin
			API.new("user32", "MessageBoxW").as_addr.threadcall_timeout(timeout, 0, strencode(name), strencode("Information"), 0)
		rescue TimeoutError
		end
	end
  end

  
	  
  
  class StructedMemory
      attr_accessor :handle, :objcount, :storage
        
      extend Seiran30
      s30local[:public] = true

	def to_int
		handle.start
	end
	
    def self.malloc(n)
	   Seiran30::Kernel32.GlobalAlloc 0, n
    end

    def self.free(ptr)
	   Seiran30::Kernel32.GlobalFree ptr
	end
        
	def self.sizeof
		self.fieldpos || s30local[:sizeof]
	end
	
	def sizeof
		self.class.sizeof
	end
	
	def self.alloc(n = 1)
		h = malloc n * sizeof
		new(h, n)
	end
	
	def self.rubyalloc(n = 1)
		len = n * sizeof
		h = "\0" * len
		x = new(memory(h).start, n)
		x.storage = h
		x
	end
	
	def self.rubyfree(ptr)
	end
	
	
	def +(offset)
		self.class.new(handle.start + offset * sizeof, objcount - offset)
	end
	alias [] +
	def self.reset_fields
	   s30local[:fields]    = []
	   s30local[:fieldpos] = 0
        end
   
        def self.fields
	   s30local[:fields] ||= []
        end
   
        def self.fieldpos
	   s30local[:fieldpos] ||= 0
        end
   
        def self.fieldpos= (n)
	   s30local[:fieldpos] = n
        end
   
	def self.addfield(name, opt = {})
	    opt = {
	      :length  => 4,
	      :getter  => Seiran30::Procs::ID, 
	      :setter  => Seiran30::Procs::ID,
	    }.update(opt)
	    if !opt[:start]
		    opt[:start]     = self.fieldpos
		    self.fieldpos += opt[:length]
	    end
	    name = name.to_sym
	    self.fields.push [name, opt]
	    self.define_field name
	end
	
	def self.define_field name
	     opt =  self.fields.find{|x| x[0] == name}[1]
	     if     opt[:getaddr] 
		     define_method(name) do
			opt[:getaddr].call(opt[:start])
		     end
	     else
		     define_method(name) do
			opt[:getter].call(handle.read(opt[:start], opt[:length]))
		     end
	     end
	     define_method("#{name}=") do |val|
		handle.write(opt[:start], opt[:length], opt[:setter].call(val))
	     end
        end
     
        def self.addpack(name, packch)
		len = [0].pack(packch).length
		addfield name,      :getter => lambda{|val| val.unpack(packch).first}, 
		                    :setter => lambda{|val| [val].pack(packch)}, 
				    :length => len
	end
			    
	def self.define_primitive(typename, packch)
		(class << self; self; end).send(:define_method, typename) do |*name|
			name.each{|x|
			   addpack x, packch
			}
		end
	end
	{
	  :int64 => "q",
	  :uint64 => "Q",
	  :int   => "i",
	  :uint  => "I",
	  :long  => "l",
	  :ulong => "L",
	  :short  => "s",
	  :ushort => "S",
	  :char  => "c",
	  :uchar => "C",
	  :int32  => "l",
	  :uint32 => "L",
	  :int16 => "s",
	  :uint16 => "S",
	  :int8   => "c",
	  :uint8  => "C",
	  :qword => "Q",
	  :dword => "L",
	  :word   => "S",
	  :byte  => "C",
	  :float => "F",
	  :single => "F",
	  :double => "D",
	  :any    => "L"
	}.each{|k, v|
	  define_primitive k, v
	}
	PTR_LEN = 4
	Nullptr = 0
	def self.pointer(klass, name)
		addfield       name,
			       :getter => lambda{|val| klass.new(val.unpack("L").first)}, 
		               :setter => lambda{|val| [val.to_int].pack("L")}, 
			       :length => PTR_LEN
	end

	def self.object(klass, name)
		addfield   name,
			       :getaddr => lambda{|val| klass.new(val)}, 
		               :setter  => lambda{|val| raise "const #{klass}"}, 
			       :length  => klass.sizeof
	end

	def self.array(klass, name, count)
		addfield   name,
			       :getaddr => lambda{|val| klass.new(val, count)}, 
		               :setter  => lambda{|val| raise "const #{klass}"}, 
			       :length  => klass.sizeof * count
	end

	def self.pack(*args)
		x = alloc 
		self.fields.each_with_index{|f, i|
		   x.send("#{f[0]}=", args[i])
		}
		x
	end
	
	def self.unpack_hash(mem)
		x = new 0
		x.handle = memory(mem)
		ret = {}
		self.fields.each{|f|
			ret[f[0]] = x.send(f[0])
		}
		ret
	end
	
	def self.unpack(mem)
		x = new 0
		x.handle = memory(mem)
		self.fields.map{|f|
			x.send(f[0])
		}
	end
	
	class << self
		alias decode unpack
		alias decode_hash unpack_hash
	end
	
	def unpack
		self.class.unpack(self.handle)
	end
	
	alias decode unpack
	
	def unpack_hash
		self.class.unpack_hash(self.handle)
	end
	
	alias decode_hash unpack_hash
	
        def initialize(h, objcount = 1)
		self.handle = Seiran30.memory(h)
		self.objcount = objcount
	end
	
	def addr
		self.handle.to_int
	end

	def set(rhs)
		self.handle = Seiran30.memory(rhs.handle.start)
		self.objcount = rhs.objcount
		self.storage = rhs.storage
		self
	end

	def copy
		x = self.class.new(0, 1)
		x.set(self)
		x
	end

	def self.[](*args)
		klass = Class.new(self)
		args.each_with_index{|x, i|
		   if Array===klass
			   klass.send x[0], x[1]
		   elsif klass.respond_to?(x)
			   klass.send x, "_#{i}"
		   else
			   klass.int x
		   end
		}
		klass
	end
	
	def free
		self.class.free(handle.start)
	end

	alias dispose free
  end
  CStruct = StructedMemory
  def scopenew(klass, n = 1)
	s30scope[:dispose].push(ret=klass.alloc(n))
	ret
  end

  def gcnew(klass, n = 1)
	klass.rubyalloc(n)
  end

  
  module CLRCall
	extend Seiran30
	##
	# :singleton-method: CLRCreateInstance
	# :args: clsid, iid, ppobj
	defapi 'mscoree', 'CLRCreateInstance'	
	##
#	CLSID_CLRMetaHost    = 0
#        IID_ICLRMetaHost     = 0
#	CLSID_CLRRuntimeHost = 0
#	IID_ICLRRuntimeHost  = 0
#	IID_ICLRRuntimeInfo  = 0
	defapiconst <<-'END MSCOREE GUID', APIHelper::FORMAT_GUID
		DEFINE_GUID(CLSID_CLRMetaHost, 0x9280188d,0x0e8e,0x4867,0xb3,0x0c,0x7f,0xa8,0x38,0x84,0xe8,0xde);
		DEFINE_GUID(IID_ICLRMetaHost, 0xd332db9e, 0xb9b3,0x4125,0x82,0x07,0xa1,0x48,0x84,0xf5,0x32,0x16);
		DEFINE_GUID(CLSID_CLRRuntimeHost, 0x90f1a06e,0x7712,0x4762,0x86,0xb5,0x7a,0x5e,0xba,0x6b,0xdb,0x02);
		DEFINE_GUID(IID_ICLRRuntimeHost, 0x90f1a06c,0x7712,0x4762,0x86,0xb5,0x7a,0x5e,0xba,0x6b,0xdb,0x02);
		DEFINE_GUID(IID_ICLRRuntimeInfo, 0xBD39D1D2, 0xBA2F,0x486A,0x89,0xB0,0xB4,0xB0,0xCB,0x46,0x68,0x91);
	END MSCOREE GUID
   'END MSCOREE GUID'
	def self.rthost
		@rthost ||= begin
			@host    = Memory.createPointer{|pp|
				CLRCreateInstance(CLSID_CLRMetaHost, IID_ICLRMetaHost, pp)
			}

			@runtime = Memory.createPointer{|pp|
				@host.virtualcall(3, strencode("v4.0.30319")+"\0\0", IID_ICLRRuntimeInfo, pp)
			}

			@rthost  = Memory.createPointer{|pp|
				@runtime.virtualcall(9, CLSID_CLRRuntimeHost, IID_ICLRRuntimeHost, pp)
			}

			@rthost.virtualcall(3)
			@rthost
		end
	end

	def self.call(appname, classname, methodname, stringarg = "")
		ret = "\0" * 4
		self.rthost.virtualcall(11, 
								strencode(appname)+"\0\0", 
								strencode(classname)+"\0\0", 
								strencode(methodname)+"\0\0", 
								strencode(stringarg)+"\0\0", 
								ret
							  )
		ret.unpack("L").first	
	end
  end

  def clrcall(appname, classname, methodname, stringarg)
	CLRCall.call appname, classname, methodname, stringarg
  end 

  module RGSSY
	include Seiran30
	extend  Seiran30
	Process = defapi('Kernel32', 'GetCurrentProcess').call
	defapi 'Kernel32', 'GetModuleFileNameW'
	defapi 'psapi', 'EnumProcessModules'

	ID_RGSS = nil
	def self.test_rgss_module(mname)
		x = defapi(mname, "RGSSGetInt")
		return false if x.address == 0
		str = "begin\n::#{self.to_s}::Process\nrescue Object\nnil\nend"
		return x.call(str) == Process
	end

	def self.init
		EnumProcessModules Process, 0, 0, (num = "\0"*4)
		num, = num.unpack("L")
		arr  = StructedMemory[:long].alloc(num * 2)   
		EnumProcessModules Process, arr, num * 8, (lnum = "\0"*4)
		(lnum.unpack("L").first).times{|i|
			filename = "\0"*2048
			GetModuleFileNameW arr[i]._0, filename, 1024
			if test_rgss_module(strdecode(filename))
				const_set :ID_RGSS, strdecode(filename).sub(/\0+$/, "")
				return ID_RGSS
			end
		}
		k = $VERBOSE
		$VERBOSE = nil
		const_set :ID_RGSS, ""
		$VERBOSE = k
		ID_RGSS
	end

	def self.id_rgss
		ID_RGSS || self.init
	end

	class ModuleInformation < StructedMemory
		##
		# :attr_accessor: base

		# :attr_accessor: size

		# :attr_accessor: entry
		
		##
		long :base, :size, :entry
	end

	class OSModule
		include Seiran30
		extend Seiran30
		defapi 'psapi', 'GetModuleInformation'
		defapi 'Kernel32', 'GetModuleHandle'
		def initialize(modname = RGSSY.id_rgss)
			@modname = modname
			setup
		end

		def setup
			h = GetModuleHandle @modname
			@info    = ModuleInformation.rubyalloc
			GetModuleInformation Process, h, @info, @info.sizeof
			@realmem = memory(@info.base)
			@mem     = @realmem.read(0, @info.size)
		end

		def find_va(strs)
			ret = []
			strs.each{|str|
				idx = -1
				while idx = @mem.index(str, idx + 1)
					ret.push(idx + @info.base) 
				end
			}
			ret
		end

		def compare_diff(a, b)
			[a - b, b - a]
		end

		def find_int(a)
			find_va([[a].pack("L")])
		end

		def rgssx_findcall(name1, name2, index)
			a = find_va(find_va([name1 + "\0"]).map{|x| [0x68, x].pack("CL")}).map{|x| x = -x}
			b = find_va(find_va([name2 + "\0"]).map{|x| [0x68, x].pack("CL")})
			c = (a + b).sort_by{|x| x.abs}
			d = (0..(c.length-2)).map{|i| [c[i+1].abs - c[i].abs, c[i], c[i+1]]}
			r = d.select{|x| x[1] < 0 && x[2] > 0}.min
			rva = r[2] - @info.base
			index.times{rva += 1 while @realmem[rva, 1] != "\xe8"; rva += 1  }
			rva -= 1
			offset,  = @mem[rva + 1, 4].unpack("L")
			realaddr = (offset + rva + 5 + @info.base) & 0xFFFFFFFF
		end
	end
	if id_rgss != ""
		RGSS = OSModule.new
		RGSSX = {
			:rb_define_method => memory(RGSS.rgssx_findcall("Bitmap", "initialize", 1)),
			:rb_intern        => memory(RGSS.rgssx_findcall("Marshal", "dump", 1)),		
			:rb_funcall       => memory(RGSS.rgssx_findcall("Marshal", "dump", 2)),
			:rb_iv_set        => memory(RGSS.rgssx_findcall("__dllname__", "__proc__", 1)),
		}
		RGSSX.each{|k, v| v.cdecl = true }
	end
  end

  if RGSSY.id_rgss != ""
  module DL_
	  C1="\x8b\x44\x24\x08\xd1\xf0\x40\xc3"
	  C2="\x8b\x44\x24\x08\x48\xc3"
  end

  RGSSY::RGSSX[:rb_define_method].call(
   (class << DL_; self.object_id*2; end),
   "dlwrap",
   DL_::C1,
   1
  )

  RGSSY::RGSSX[:rb_define_method].call(
   (class << DL_; self.object_id*2; end),
   "dlunwrap",
   DL_::C2,
   1
  )

  def dlwrap(x)
	  DL_::dlwrap(x)
  end
  def dlunwrap(x)
	  DL_::dlunwrap(x)
  end
  end
  class Memory
	attr_accessor :storage
	def self.malloc(n)
	   new Seiran30::Kernel32.GlobalAlloc(0, n), n
	end

	def self.fromStringBuffer(str)
	   x = malloc(str.length)
	   x[0, str.length] = str
	   x
	end

        def self.free(ptr)
	   Seiran30::Kernel32.GlobalFree ptr.to_int
	end

	def free
		self.class.free(self) if @start != 0
		@start = 0
	end

	alias dispose free
	def self.fromCallback(type = :stdcall, arity = nil, &bl)
		arity ||= bl.arity
		arity = -1 if type == :cdecl
		functype = (arity == -1 ? [:cdecl] : [:stdcall, arity])
		storage = bl
		blk = bl
		if(functype[0] == :stdcall)
			translate = lambda{|ebp| bl.call(memory(ebp).read(8, arity*4).unpack("L*")) }
			storage = [bl, translate]
			blk = translate
		end
		that = self
		code = BaseVM.new do
			function( *functype ) do
				loadframe
				shl
				inc
				push
				pushi [dlwrap(blk), RGSSY::RGSSX[:rb_intern].call("call\0"), 1].reverse
				load  RGSSY::RGSSX[:rb_funcall].start
				call
				unalloc 16
				shr
			end
		end.result
		ret = malloc(code.length)
		ret[0, code.length] = code
		ret.cdecl = functype[0] == :cdecl
		ret.storage = storage
		ret
	end
  end

  def callback(type = :stdcall, arity = nil, &bl)
	  Memory::fromCallback(type, arity, &bl)
  end

 
  
  def _win32api_setaddr(wapi, addr)
     r = wapi.instance_eval { @realaddr =  addr }
     RGSSY::RGSSX[:rb_iv_set].call(wapi.object_id*2, "__proc__\0", dlwrap(r))
  end


=begin
   3 / 30 Dosu stuff
   DOESU 
   Document Object Elemental Structure Unit

   generate objects from documents and vice versa
=end

   # General-purposed state machine
   module StateMachineBase
      include DSLBase

      def reset
	@final = [:__fail__, :__done__]
	@_befores = {}
	@_afters  = {}
	@_pre     = {}
	@_next    = {}
	@_keystate = []
	@_state_stack = [:init]
      end

      def init
	transit :__done__
      end

      def transit(state)
	@_state_stack[-1] = state
      end

      def before(a, b, &bl)
	@_befores[a] ||= {}
	@_befores[a][b] = bl
      end

      def after(a, b, &bl)
	@_afters[a] ||= {}
	@_afters[a][b] = bl
      end

      def nextstate(a, b)
	@_next[a] = b
      end

      def pushstate(s)
	      @_state_stack.push s
      end

      def popstate
	      @_state_stack ||= []
	      if @_keystate[-1] == @_state_stack.length - 1
		      @_keystate.pop
	      end
	      @_state_stack.pop
      end

      def pushkeystate(s)
	      pushstate s
	      @_keystate.push @_state_stack.length - 1
      end


      def update	
	transited = true
	while transited
	    transited = false
  	    (@_befores[@_state_stack[-1]] ||= {}).each{|k, v|
		break(transited = transit(k)) if v.call
	    } 
	end
	send @_state_stack[-1] if running?
	transited = true
	while transited
	    transited = false
  	    (@_afters[@_state_stack[-1]] ||= {}).each{|k, v|
		break(transited = transit(k)) if v.call
	    } 
	end
	transit( @_next[@_state_stack[-1]]) if @_next[@_state_stack[-1]]
      end

      def running?
	!@final.include?(@_state_stack[-1])
      end

      def accept?
	@_state_stack[-1] == :__done__
      end

      def reject?
	@_state_stack[-1] == :__fail__
      end
   end

   def randstr(length)
	(0...length).map{ rand(256).chr }.join
   end

   def ruby_syntax_check(a)
	str = %{
		BEGIN { throw :ok, true }
		#{a}
	}
        begin
		catch(:ok){
			eval str
			raise SyntaxError, '?'
		}
	rescue SyntaxError
		raise $!.class, $!.message, $!.backtrace
	end
   end


   module RPNMachine
	
	def push(*a)
		@stack.concat a
		@modified = true unless a.empty?
	end

	def pop(*a)
		ret = @stack.pop *a
		@modified = true if ret != []
		ret
	end

	def top
		@stack[-1]
	end

	def content
		@stack[0..-1]
	end
   end
   
   #
   # 3.1 Document => Object
   # Templated parser of a recursive document, see MyJSONParser
   #
   module DocBasicUnitRead
     include RPNMachine
     MonoHash = Struct.new(:key, :value)
     def parse(str)
	@origstr = str[0..-1]
	@str     = str[0..-1]
	@stack   = []
	pre_loop
	loop do
		len = @str.length
		update
		raise "Unknown char #{@str[0, 1].inspect} | #{@str[1, 10].inspect}" if len == @str.length
		return post_loop if @str == ""
	end
	post_loop
	nil
     end

     def pre_loop
     end

     def post_loop
	top
     end

     def str_open
        push ""
     end

     def str_close

     end

     def concat(s)
	top.concat(s)
     end

     def array_open
	push []
     end

     def literal(a)
        push a
     end

     def comma
	a = pop
     	case top
		when Array
			top << a
		when nil
			push a
		when MonoHash
			top.value = a
			comma
		when Hash, Struct
			if MonoHash === a
				top[a.key] = a.value
			else
				raise "#{a.class} -> #{Hash}"
			end
		else
			if MonoHash === a
				top.send("#{a.key}=", a.value)
			else
				raise "#{a.class} -> #{Any Object}"
			end
	end
     end

     def hash_open
  	push({})
     end

     def hash_key
	push MonoHash.new(pop)
     end

     def array_close
 	comma
     end

     def hash_close
        comma
     end	
    
     def lookleft(reg)
	yield $~ if @str.slice!(reg)
     end

   end

   #
   # 3.2 Object => Document
   module DocBasicUnitWrite
	include RPNMachine
	MetaStr       = Struct.new(:val)
	Option        = Struct.new(:key, :value)
	OptionManip   = Struct.new(:key, :proc)
	def generate(obj)
	    @result = ""
	    @object = obj
	    @stack  = [obj]
	    @config ||= {}.update((class << self; self; end)::DEFAULTCHAR)
	    @option = {:indent => 0 }
	    loop do
		@modified = false
		update
		break if accept?
		if !@modified
			raise "Don't know how to generate #{@stack[-1]}\n#{@stack[-2..-5]} | #{@stack[-1]}"
		end
	    end
	    @result
	end

	def meta(str)
		push MetaStr.new(str)
	end

	def dispatch
		a = pop
		case a
		when Array   then array(a)
		when Hash    then hash(a)
		when String  then string(a)
		when Integer then integer(a)
		when Symbol  then symbol(a)
		when Float   then float(a)
		when Option  then @option[a.key] = a.value
		when OptionManip  then @option[a.key] = a.proc.call(@option[a.key])
		when MetaStr then @result << a.val
		else
			push a
			@modified =false
		end
		transit :__done__ if @stack.empty?
	end

	DEFAULTCHAR = {
		:array_open    => MetaStr.new("["),
		:array_close   => MetaStr.new("]"),
		:array_comma   => MetaStr.new(", "),
		:hash_open     => MetaStr.new("{"),
		:hash_close    => MetaStr.new("}"),
		:hash_comma    => MetaStr.new(", "),
		:hash_key      => MetaStr.new(" => "),
	}

	def array(a)
		push @config[:array_close]
		push OptionManip.new :indent, proc{|x| x + 1}
		a.reverse.each_with_index{|x, i|
			push @config[:array_comma] if i > 0
			push x
		}
		push OptionManip.new :indent, proc{|x| x - 1}
		push @config[:array_open]
	end

	def hash(a)
		push @config[:hash_close]
		push OptionManip.new :indent, proc{|x| x + 1}
		a.to_a.reverse.each_with_index{|x, i|
			k, v = x
			push @config[:hash_comma] if i > 0
			push v
			push Option.new(:hashkey, false)
			push @config[:hash_key]
			push k
			push Option.new(:hashkey, true)
		}
		push OptionManip.new :indent, proc{|x| x - 1}
		push @config[:hash_open]
	end

	def translate(str)
		a = str[0..-1]
		{	"\a" => "\\a",
			"\b" => "\\b",
			"\f" => "\\f",
			"\n" => "\\n",
			"\p" => "\\p",
			"\r" => "\\r",
			"\t" => "\\t",
			"\v" => "\\v",
			"\"" => "\\\"",
			"\'" => "\\\'",
		}.each{|k, v|
			a.gsub!(k, v)
		}
		a.gsub!(/[^[:print:]]/){  $&.unpack("C*").map{|x| "\\x%02x" % x}.join }
		'"' << a << '"'
	end

	def string(a)
		meta translate a
	end

	def integer(a)
		meta a.to_s
	end

	def float(a)
		meta a.to_s
	end

	def init
		dispatch
	end

	def symbol(a)
		if a.to_s[/^[A-Za-z_][A-Za-z0-9_]*$/]
			meta a.to_s
			meta ":"
		else
			string a.to_s
			meta  ":"
		end
	end
end

  class DocUnitRead
	  include StateMachineBase
	  include DocBasicUnitRead
  end
  
  class DocUnitWrite
	  include StateMachineBase
	  include DocBasicUnitWrite
  end
     	 
   #
   # Example Class for StateMachine + DocBasicUnitRead
   # Not standard JSON
   #
   class MyJSONParse < DocUnitRead
	def init
		case 
		when @str.slice!(/^\s+/) # skip
		when @str.slice!(/^\[/)							 then array_open
		when @str.slice!(/^\{/) 						 then hash_open
		when @str.slice!(/^(,\s*)?\]/) 						 then array_close
		when @str.slice!(/^(,\s*)?\}/) 						 then hash_close
		when @str.slice!(/^,/) 							 then comma
		when @str.slice!(/^:/) 							 then hash_key
		when @str.slice!(/^0[0-7]*/) 						 then literal(Integer($&))
		when @str.slice!(/^[0-9]+(\.[0-9]*)?([eE][-+]?\d+)?/) 			 then literal((Integer($&) rescue Float($&)))
		when @str.slice!(/^0x[0-9A-Fa-f]+/) 					 then literal(Integer($&))
		when @str.slice!(/^"/)  						 then str_open; pushstate :string
		end
	end

	def string
		case 
		when @str.slice!(/^\\([abfnprtv\"\\\'])/)				 then concat $1.tr("abfnprtv\"\\\'", "\a\b\f\n\p\r\t\v\"\\\'")
		when @str.slice!(/^\\x([0-9A-Fa-f]{1, 2})/) 				 then concat $1.to_s(16).chr
		when @str.slice!(/^\\0([0-7]{0, 2})/) 					 then concat $1.to_s(8).chr	
		when @str.slice!(/^"/) 							 then str_close; popstate
		else concat(@str.slice!(0, 1))
		end
	end
    end

   #
   # Example Class for StateMachine + DocBasicUnitWrite
   # Not standard JSON
   #
   class MyJSONWrite < DocUnitWrite
	DEFAULTCHAR = {}.update(DocBasicUnitWrite::DEFAULTCHAR)
	DEFAULTCHAR.update({ :hash_key => MetaStr.new(": ") })
	def integer(a)
		if @option[:hashkey]
			string a.to_s
		else
			meta a.to_s
		end
	end
	def float(a)
		if @option[:hashkey]
			string a.to_s
		else
			meta a.to_s
		end
	end
   end
   ExprNode = Struct.new(:op, :type, :args, :lb, :rb)
   class ExprNode
		def inspect
				"(#{op} #{args.join(", ")})"
		end
		alias to_s inspect
	end
   #
   #  3.3 Expression => Object
   #
   module ExprBasicUnitRead
	include RPNMachine
	Node = ExprNode
	class Stack
		include RPNMachine
		def initialize
			clear
		end
		def clear
			@stack = []
		end
	end
	
        def parse(str)
	     @str         = str[0..-1]
	     @orig        = str[0..-1]
	     @stack      = []
	     @opstack   = Stack.new
	     @bracket   = Stack.new
	     pre_loop
	     loop do
		len = @str.length
		update
		raise "Unknown char #{@str[0, 1].inspect} | #{@str[1, 10].inspect}" if len == @str.length
		return post_loop if @str == "" 
	     end
	     post_loop
        end
        
        def pre_loop
	end
	
	def post_loop
		finish
		if @stack.size > 1
			Node.new(nil, :bracket,  @stack)
		else
			@stack.last
		end
	end
	
	def object(obj)
		push obj
	end
	
	def bracket(lb, rb, ch = nil)
		@brackets ||= {}
		@brackets[lb] = [lb, rb, ch, :left]
		@brackets[rb] = [lb, rb, ch, :right]
	end
	
	def enter_bracket(lb)
		@bracket.push lb
		@stacks ||=[]
		@stacks.push [@stack, @opstack]
		@opstack = Stack.new
		@stack = []
	end
	
	def leave_bracket(rb)
		lb = @bracket.pop
		raise "Bracket #{lb} does not match #{rb}" if !@brackets[lb] || @brackets[lb][1] != rb
		finish
		s, o = @stack, @opstack
		@stacks ||=[]
		@stack, @opstack = @stacks.pop
		if @brackets[rb][2]
			@stack.push Node.new(@brackets[rb][2], :bracket, s, lb, rb)
		else
			@stack.concat s
		end
	end
	
	def push_op(m)
		case @prec[m][:type]
			when :left, :right
				obj = pop(2)
				push Node.new(m, :binary, obj)
			when :unaryl, :unaryr
				obj = pop(1)
				push Node.new(m, @prec[m][:type], obj)
		end
	end
	
	def left(op, level)
		@prec ||= {}
		@prec[op]  = {
			:left    => level * 3 + 1,
			:right  => level * 3,
			:arity   => 2,
			:type   => :left,
		}
	end
	
	def right(op, level)
		@prec ||= {}
		@prec[op]  = {
			:left    => level * 3,
			:right  => level * 3 + 1, 
			:arity   => 2,
			:type   => :right,
		}
	end
	
	def unaryl(op, level)
		@prec ||= {}
		@prec[op] = {
			:left => 0,
			:right => level * 3 + 2,
			:arity => 1,
			:type => :unaryl,
		}
	end
	
	def unaryr(op, level)
		@prec ||= {}
		@prec[op] = {
			:left => level * 3 + 2,
			:right => 0,
			:arity => 1,
			:type => :unaryr,
		}
	end
	
	def toleft(a)
		return a if Array === a && a.size == 2
		@prec ||= {}
		[@prec[a][:left], a]
	end
	
	def toright(a)
		return a if Array === a && a.size == 2
		@prec ||= {}
		[@prec[a][:right], a]
	end
	
	def operator(a)
		prec, sym = toright(a)
		while @opstack.top != nil && toleft(@opstack.top)[0] >=prec
			push_op @opstack.pop[1]
		end
		@opstack.push [prec, sym]
	end
	
	def finish
		while @opstack.top != nil
			push_op @opstack.pop[1]
		end
	end
	
	
end

   #
   #  3.4 Object(Node) => Expression
   #
   module ExprBasicUnitWrite
	include RPNMachine
	Node = ExprNode
	MetaStr = Struct.new(:val)
        DEFAULTCHAR = {
		:lb   => "(",
		:rb   => ")",
		:spc => " ",
	}
	def generate(node)
	    @result = ""
	    @object = node
	    @stack  = [node]
	    @config ||= {}.update((class << self; self; end)::DEFAULTCHAR)
	    @option = {:indent => 0 }
	    loop do
		@modified = false
		update
		break if accept?
		if !@modified
			raise "Don't know how to generate #{@stack[-1]}\n#{@stack[-2..-5]} | #{@stack[-1]}"
		end
	    end
	    @result
        end
        def init
		dispatch
	end
	def meta(str)
		push MetaStr.new(str)
	end
	def dispatch
		v = pop
		case v
			when Node
				case v.type
				when :binary  then 
					meta @config[:rb]
					push v.args[1]
					meta @config[:lb]
					meta v.op.to_s
					meta @config[:rb]
					push v.args[0]
					meta @config[:lb]
				when :unaryl  then 
					meta @config[:rb]
					push v.args[0]
					meta @config[:lb]
					meta v.op.to_s
				when :unaryr  then 
					meta v.op.to_s
					meta @config[:rb]
					push v.args[0]
					meta @config[:lb]
				when :bracket then
					meta v.rb.to_s
					v.args.reverse.each{|x|
						meta @config[:spc]
						push x
					}
					meta v.lb.to_s
				else
					raise "Don't know how to dispatch node #{v.type}"
				end
			when MetaStr
				@result << v.val
			when Fixnum
				@result << v.to_s
			else
				raise "Don't know how to dispatch #{v.class} #{v.inspect}"
		end
		transit :__done__ if @stack.empty?
	end
    
   end
   
   class ExprUnitRead
	   include StateMachineBase
	   include ExprBasicUnitRead
   end
   
   class ExprUnitWrite
	   include StateMachineBase
	   include ExprBasicUnitWrite
   end
   
   #Second Definitions
   module APIHelper
	module VB6Parser
		module ConstParser
			def self.autotype(str)
				case str
				when /&H(\d+)/ then $1.to_i(16).to_s
				when /\d+/       then $1
				else
					str
				end
			end
			def self.parse(doc)
				ret = {}
				doc.scan(/Const (\S+) = ([^\n']+)/) do
					ret[$1] = autotype($2)
				end
				ret
			end
		end
		
		TypeParser = DocUnitRead.new do
			def pre_loop
				hash_open
			end
			def post_loop
				hash_close
				super
			end
			
			
			def init
				lookleft(/^\s+/) do return end
				lookleft /^\AType\s+(\S+)/i do |m| 
					push m[1]
					hash_key
					array_open
					return
				end
				
				lookleft /^\AEnd Type/i do |m| 
					array_close
					return
				end
				
				lookleft /^\A\s*(\S+)[  ]+As[ ]+(.+)/i do |m|
					push [m[1], m[2].downcase]
					comma
					return
				end
				
				lookleft /^\A.+?$/ do
					return
				end
			end
		end
			
		def self.parse(doc)
			{
				:const => ConstParser.parse(doc),
				:type   => TypeParser.parse(doc)
			}
		end
	end
   end
   
   

    
    #
    #
    # ?/ 30 Embedded Data
    #
    #
    def zlib(str, level = 9)
	    Zlib::Deflate.deflate str, level
    end
    
    def  unzlib(str)
	    Zlib::Inflate.inflate str
    end

    def  base64(str)
            [str].pack("m")
    end

    def unbase64(str)
            str.unpack("m").first
    end
    
    def unmime(str)
	    str.unpack("M").first
    end
    
    def mime(str)
	    [str].pack("M")
    end
    
    def isutf8(str)
	 str.unpack("U*")
	 true
    rescue
         false
    end
    
    def isoem(str)
	    isutf8 strdecode(strencode(str, 0))
    end
    
    def iswide(str)
	    isutf8 strdecode str
    end
    
    def template(str)
	    
    end
    
    
    class Promise
	attr_accessor :env
	def initialize(*a)
		@arr = a
	end
	def done(a = nil, &bl)
		@arr.push a || bl
		self
	end
	def await(t = nil, env = {})
		return true if @arr.empty?
		self.env ||= env
		if t
			x = @arr[0]
			ret = x.await t, self.env
			if ret
				self.env[:value] ||= []
				self.env[:value].push x.value if x.respond_to?(:value)
				@arr.shift
				return @arr.empty?
			else
				return false
			end
		else
			until @arr.empty?
				await 0.1,  env
			end
		end
	end
	
	def done?(env = {})
		await 0.01, (self.env ||= env)
	end
	
	def value
		self.env
	end
    end

    def promise(lb = nil, &bl)
	    Promise.new(lb || bl)
    end
    
    class ::Proc
	    alias await call
    end
    
    
    #
    #
    # ?/ 30 the VM
    #
    #
    
    
    class X86VM
	include RPNMachine
	include StateMachineBase
	include BinaryGenerator
	include DSLBase
	def reset
		@stack = []
		@result = []
		@code = ""
		@labels = {}
		@relocates = {}
		super
	end
	R = [:eax, :ecx, :edx, :ebx, :esp, :ebp, :esi, :edi]
	JMP = [:jo, :jno, :b, :jnb, :je, :jne, :jbe, :jnbe, :js, :jns, :jp, :jnp, :jl, :jnl, :jle, :jnle]
	R.each_with_index{|x, i|
		define_method x do 
			push [:reg, i]
		end
	}
	
	def disp32(x)
		push [:disp32, x]
	end
	
	def indir(offset = nil)
		if !offset
			push [:indir, pop]
		else
			if offset >= -128 && offset <= 127
			    push [:indiradd8, pop + [offset]]
			else
			    push [:indiradd, pop + [offset]]
			end
		end
	end
	
	def sib(base = :eax, sc = :eax, scale = 1, offset = nil)
		case 
			when !offset
				push [:sib, [R.index(base), R.index(sc), [1,2,4,8].index(scale)]]
			when offset  >= -128 && offset <= 127
				push [:sib8, [R.index(base), R.index(sc), [1,2,4,8].index(scale)], offset]
			else
				push [:sib32, [R.index(base), R.index(sc), [1,2,4,8].index(scale)], offset]
		end
	end
	
	def error(a)
		raise "X86Machine #{a}"
	end
	
	def modrm(a)
		case a.map{|i| i.first }
			when [:reg, :reg]
				yield
				db (0b11 << 6) | a[0][1] << 3 | a[1][1]
			when [:reg, :indir]
				yield 
				db a[0][1] << 3 | a[1][1][1]
			when [:reg, :indiradd]
				yield
				db (0b10 << 6) | a[0][1] << 3 | a[1][1][1]
				dd a[1][1][2]
			when [:reg, :indiradd8]
				yield
				db (0b01 << 6) | a[0][1] << 3 | a[1][1][1]
				db a[1][1][2]
			when [:reg, :disp32]
				yield
				db 5+a[0][1] * 8
				dd a[1][1]
			when [:reg, :sib]
				yield 
				db 0x04 + a[0][1] * 8
				db a[1][1][1] << 3 | a[1][1][0] | a[1][1][2] << 6
			when [:reg, :sib8]
				yield 
				db 0x44 + a[0][1] * 8
				db a[1][1][1] << 3 | a[1][1][0] | a[1][1][2] << 6
				db a[1][2]
			when [:reg, :sib32]
				yield 
				db 0x84 + a[0][1] * 8
				db a[1][1][1] << 3 | a[1][1][0] | a[1][1][2] << 6
				dd a[1][2]
		end
		nil	
	end
	
	def modrm_reverse(a)
		case a.map{|i| i.first }
			when [:indir, :reg], [:indiradd, :reg], [:indiradd8, :reg], [:disp32, :reg], [:sib, :reg], [:sib8, :reg], [:sib32, :reg]
				 modrm a.reverse do |r|  yield r end
				
		end
		nil
	end
	
	def add
		a = pop(2)
		modrm(a) do            db 0x03 end
		modrm_reverse(a) do db 0x01 end
	end
	
	def self.define_binary_op(name, opcode)
		define_method(name) do |*args|
			a = pop(2)
			modrm(a) do db opcode  | 0b10 end
			modrm_reverse(a) do db opcode & ~0b10 end
		end
	end
	def self.define_i32_op(name, opcode)
		define_method(name) do |arg|
			db opcode
			dd arg
		end
	end
	
	define_i32_op :pushi, 0x68
	define_binary_op :test, 0x85
	
	[:add, :or, :adc, :sbb, :and, :sub, :xor, :cmp].each_with_index{|x, i|
		define_binary_op x, i * 8 + 3
		define_i32_op  :"#{x}eax", i*8+5
		define_method :"#{x}i" do |reg, val|
			if val >= -128 && val <= 127
				db 0x83
				db 0b11 << 6 | R.index(reg) << 3 | 0
				db val
			else
				db 0x81
				db 0b11 << 6 | R.index(reg) << 3 | 0
				dd val
			end
		end
	}
	
	define_binary_op :mov, 0x8b
	def pushr(*)
		db 0x50 + pop[1]
	end
	
	def popr(*)
		db 0x58 + pop[1]
	end
	
	def movi(reg, val)
		db 0xb8 + R.index(reg)
		dd val
	end
	
	def movbi(reg, val)
		db 0xb0 + R.index(reg), val
	end
	
	def incr(*)
		db 0x40 + pop[1]
	end
	
	def decr(*)
		db 0x48 + pop[1]
	end
	
	def self.define_single_modrm(name)
		define_method name do |a|
			a = [[:reg, 0], pop]
			modrm(a) do yield end
		end
	end
	
	define_single_modrm :popm do db 0x8f end
	
	def label(name)
		@labels[name] = @code.length
	end
	
	def relative(label)
		@relocates[@code.length] = [:relative, label]
		dd 0
	end
	
	def absolute(label)
		@relocates[@code.length] = [:absolute, label]
		dd 0
	end
	
	def relocate(baseaddr = 0)
		@relocates.each{|k, v|
			type, label = v
			raise if !@labels[label] && !(Integer === label)
			label = @labels[label] + baseaddr if @labels[label]
			if type == :relative
				@code[k, 4] = [label - (k+baseaddr+4)].pack("L")
			elsif type == :absolute
				@code[k, 4] = [label].pack("L")
			end
		}
		self
	end
	
	JMP.each_with_index{|x, i|
		define_method x do |label|
			db 0x0f
			db 0x80 + i
			relative label
		end
	}
	
	def result(baseaddr = 0)
		relocate baseaddr
		super()
	end
	
	def callrel label
		db 0xe8
		relative label
	end
	
	def jmprel label
		db 0xe9
		relative label
	end
	
	def dd(a)
		case a
			when String
				super [a].pack("p").unpack("L").first
			else
				super a
		end
	end
	
	def size
		@code.size
	end
	def leave; db 0xc9; end
	def retn; db 0xc3; end
	
	def assemble
		x = Memory.malloc(size)
		x[0, size] = result x.to_int
		ou = {}
		@labels.each{|k, v| ou[k] = v + x.to_int}
		x.storage = {:labels => ou}
		x
	end
   end

   class PlusVM 
	include DSLBase
	def reset
		@vm = X86VM.new
	end
	def load(val) @vm.movi :eax, val end
	def ldarg(a) @vm.mov @vm.eax, [@vm.ebp, @vm.indir(4 + a * 4)] end
	def starg(a) @vm.mov [@vm.ebp, @vm.indir(4 + a * 4)], @vm.eax end
	def push; @vm.pushr @vm.eax; end
	def pop; @vm.popr @vm.eax; end
	def add; @vm.popr @vm.edx; @vm.add @vm.eax, @vm.edx; end
	def procbegin; @vm.pushr @vm.ebp; @vm.mov @vm.ebp, @vm.esp; end
	def procend; @vm.leave; @vm.retn; end
	def assemble
		@vm.assemble
	end
    end

    def dfs(stack, result = [], &block)
	    yield stack.method(:concat), stack.pop, result until stack.empty?
	    result
    end
    
    def bfs(queue, result = [], &block)
	    yield queue.method(:concat), queue.shift, result until queue.empty?
	    result
    end
   
   
   #
   #
   # ?/30 Contract
   #
   #
   class Interface
      attr_accessor :arr, :neg
      def initialize(arr = [], neg = [])
         @arr = arr
         @neg = neg
      end
      def ===(a)
         @arr.all?{|i| a.respond_to?(i)} && @neg.none?{|i| a.respond_to?(i)}
      end
      def +(a)
 	case a
		when Array
		             Interface.new(@arr | a, @neg - a)
		when Interface
		             Interface.new((@arr | a.arr) - a.neg, (@neg | a.neg) - a.arr)
	end
      end
      def -(a)
	case a
		when Array
		             Interface.new(@arr - a, @neg | a)
		when Interface
		             Interface.new((@arr - a.arr) | a.neg, (@neg - a.neg) | a.arr)
	end
      end
   end

   def interface(*args)
       Interface.new args
   end

   def sigeq(a, b)
	@_sigst ||= []
	case a
		when	Symbol
			r = a.to_s[0]
			if r[/^[a-z_]/]
				b.respond_to?(a)
			else
				if !@_sigst[-1][r]
					@_sigst[-1][r] = b.class
					true
				else
					@_sigst[-1][r] === b
				end
			end
		when     Array
			a.length === b.length && a.zip(b).all?{|x| sigeq x[0], x[1]}
		else
			a === b
	end
   end
=begin
class Object
   def add(a, b)
	a+b
   end
   def add_slow(a, b)
     while b > 0
        a = a.succ
        b -= 1
     end
     a
   end
   sig :add,  [:A, :A] => interface, [interface(:succ), interface(:-)] => [interface, :add_slow],
end

class Object
   sig :fibImpl, [0,   :A, :A] => [:A, lambda{ @_[2]}],
	       [:A, :A, :A] => [:A, lambda{ fibImpl(@_[0] - 1, @_[2], @_[1]+@_[2] ) }]
   sig :fib,       [:A] => [:A, lambda{fibImpl @_[0], 0, 1  }]
end

10.times{|i| p fib(i)}
p add("abc", 5)

=end   
  def sig(name, opt)
	types  = opt.to_a.select{|x| x[0].is_a?(Array)}
	special_class.class_eval do
		unless method_defined?(name)
			define_method(name) do |*| end
		end
		newname = gen_id
		alias_method newname, name
		typename = gen_id
		define_method(typename) do types end
		class_eval %{
			def #{name}(*args, &block)
				#{typename}.each{|k, v|
					@_sigst ||= []
					@_sigst.push({})

					if sigeq(k, args)
						case v
						when Array
							ret = v[0]
							rel = v[1]
						else
							ret, rel = v, #{newname.inspect}
						end
						case rel
						when Symbol
							r = send(rel, *args, &block)
						when Proc
							s = @_
							@_ = args
							r = instance_eval0(&rel)
							@_ = s
						end
						if !sigeq(ret, r)
							warn "Returned Type does not match \#{ret} but got \#{r.inspect}"
						end
						@_sigst.pop
						return r
					end
					@_sigst.pop
				}
				raise ArgumentError, "Got \#{args.inspect} but no sig matched #{name.inspect}"				
			end
		}
	end
   end
    #
    #
    # ?/ 30 Document Model
    #
    #
    class DocumentModel
	def initialize(root)
		@root = root
	end
	
	def selectfunc(x)
		case x
			when "//"
				lambda{|x| x[:_root] = true}
			when Proc, Range
				x
			when "*"
				lambda{|*| true}
			else 
				nil
		end
	end
	
	def movefunc(x)
		case x
			when "*", "v"
				lambda{|x| x[:_c]}
			when ">"
				lambda{|x| [x[:_n]].compact}
			when "<"
				lambda{|x| [x[:_p]].compact}
			when "^"
				lambda{|x| [x[:_parent]].compact}
		end
	end
	
	def query(args)
		@root[:_root] = true
		nodes = dfs([@root]){|dfs, x, result|
			    result << x
			    if x[:_c]
				    x[:_c].each_with_index{|e, i|
					e[:_n] = x[:_c][i+1]
					e[:_p] = i > 0 ? x[:_c][i-1] : nil
					e[:_parent] = x
				    }
				    dfs.call(x[:_c]) 
			    end
		}
		args.each{|x|
			case
				when y = selectfunc(x)
					nodes = nodes.select{|i| y === i}
				when y = movefunc(x)
					nodes = nodes.inject([]){|a, b|a.concat y.call(b)}
				end
		}
		nodes
	end
	alias [] query
    end
	
    class XSRandom
	def initialize(seed = nil, y = nil, z = nil)
		@x    = seed ||= Kernel.rand(U32MAX)
		@y    = y    ||= 0
		@z    = z    ||= 0		
	end
	def randu32
		@x ^= @x << 16;	@x &= 0xFFFFFFFF
		@x ^= @x >> 5 ; @x &= 0xFFFFFFFF
		@x ^= @x << 1 ; @x &= 0xFFFFFFFF
		t = @x
		@x = @y
		@y = @z
		@z = t ^ @x ^ @y
	end
	U32MAX = 1 << 32
	def randfixnum(fixnum)
		delta = U32MAX % fixnum
		limit = U32MAX - delta
		while true
			a = randu32
			return a % fixnum if a < limit
		end
	end
	def randbignum(bignum)
		u = bignum.size
		if u % 4 != 0
			u += 4 - u % 4
		end
		umax = 1 << (u * 8)
		tm   = u / 4  # vcode: / 
		delta = umax % bignum
		limit = umax - delta
		while true
			a = 0
			tm.times{|x| a = a << 32 | randu32}
			return a % bignum if a < limit
		end
	end
	
	def randint(integer)
		case integer
			when Fixnum then randfixnum(integer)
			when Bignum then randbignum(integer)
		end
	end
	
	def randfloat(float)
		randint((float / Float::EPSILON).to_i) * Float::EPSILON  # vcode: /
	end
	
	def randintrange(v)
		st = v.first
		ed = v.last
		ed += 1 if !v.exclude_end?
		st + randint(ed - st)
	end
	
	def randfloatrange(v)
		st = v.first
		ed = v.last
		ed += Float::EPSILON if !v.exclude_end?
		st + randfloat(ed - st)
	end
	
	
	def rand(v)
			case v
				when 0       then randfloat(1.0)
				when Integer then randint(v)
				when Float   then randfloat(v)
				when Range
					return randfloatrange(v) if Float === v.first || Float   === v.last
					return randintrange(v) if Integer === v.first || Integer === v.last
					raise "Can't generate #{v.first.class} ... #{v.last.class}"
				end
	end
	
	def randstr(len = 32, charset = "0123456789ABCDEF")
		ret = ""
		len.times{|x| ret << charset[randfixnum(charset.size)] }
		ret
	end
    end
    #
    #
    #  5 / 30 Connectivity
    #
    #
    module Slot
	def initSlot
		@_slot = {}
		@_slotcookie = {}
		@_random = XSRandom.new
	end
	def connect(obj = nil, &bl)
		cookie = @_random.randstr
		cookie = @_random.randstr if @_slot.include?(cookie)
		a = @_slot[cookie] = obj || bl
		@_slotcookie[a] = cookie
		cookie
	end
	def disconnect(obj_token)
		return @_slot.delete obj_token if @_slot[obj_token]
		if c = @_slotcookie[obj_token]
			@_slot.delete c
			@_slotcookie.delete obj_token
		end
	end
	def call(*args)
		@_slot.each{|k, v|
			ret = v.call(*args)
			case 
				when ret == nil,  ret == false, ret == :continue
				when ret == true, ret == :break
					break
				when Array === ret && ret[0] == :return
					return ret[1]
			end
		}
	end
	def +(obj = nil, &bl)
		connect(obj||bl)
		self
	end
	alias -          disconnect
	alias push       connect
	alias add        connect
    end

    class SlotObject
	include Slot    
	def initialize(obj)
		@obj = obj
		initSlot
	end
	def call(*args)
		super	*args
	end
        def clear
		@_slot = {}
		@_slotcookie = {}
        end
	alias fire       call
	alias raiseevent call
    end

    def define_signal *syms
	syms.each{|sym|
		special_class.class_eval %!
			def on#{sym}
				@#{sym} ||= Seiran30::SlotObject.new(self)
			end
			attr_writer "on#{sym}"
			def #{sym}(*args)
				on#{sym}.call(*args)
			end
		!
	}
    end

    
    def require(*args)
	  a = (s30global[:require] ||= []).last
	  if a
	  	a.call(Kernel.method(:require), *args)
	  else
	    super
	  end
	end
	
	
	def push_require(a)
	  (s30global[:require] ||= []) << a
	end
	
	def pop_require
	  (s30global[:require] ||= []).pop
	end
	
	module SimpleDL
	   extend Seiran30
	   declapi 'urlmon', 'URLDownloadToCacheFile'
	   def download(url, retries = 5)
	     begin
	     	url << (url['?'] ? "&" : '?') << ".randstamp=#{rand}"
		 	URLDownloadToCacheFile 0, url, (buf="\0"*4096), 4096, 0, 0
			open(buf.sub(/\0+$/, ''), 'rb') do |f| f.read end
		 rescue
			retry if (retries -= 1) > 0
			raise $!.class, $!.message, $!.backtrace
		 end 
	   end
	end
	
	include SimpleDL

	module Crypt
	  class CryptContext
	    extend Seiran30
	    declapi 'advapi32', *%w{
			CryptAcquireContext
			CryptReleaseContext
			CryptCreateHash
			CryptDestroyHash
			CryptHashData
			CryptGetHashParam
			CryptGenRandom
		}
		defapiconst <<-'End VB6 Const'
			Private Const PROV_RSA_FULL = 1
			Private Const CRYPT_NEWKEYSET = &H8
			Private Const ALG_CLASS_HASH = 32768
			Private Const ALG_TYPE_ANY = 0
			Private Const ALG_SID_MD2 = 1
			Private Const ALG_SID_MD4 = 2
			Private Const ALG_SID_MD5 = 3
			Private Const ALG_SID_SHA1 = 4 
			Private Const HP_HASHVAL = 2
			Private Const HP_HASHSIZE = 4 
		End VB6 Const
	   'End VB6 Const'
		def pInt
		  a = "\0"*4
		  yield a
		  a.unpack("L").first
		end
		
		def initialize
		  @context = pInt do |here| CryptAcquireContext here, 0, 0, PROV_RSA_FULL, 0 end
		end
		
		def random_bytes(len)
		  buf = "\0" * len
		  CryptGenRandom @context, buf.length, buf
		  buf
		end
		
	    def setupencrypt(algorithm = :md5)
		  alg = self.class.const_get("ALG_SID_#{algorithm.upcase}") | ALG_CLASS_HASH | ALG_TYPE_ANY		  
		  @hash    = pInt do |here| CryptCreateHash @context, alg, 0, 0, here end
		  self
		end
		
		def push(str)
		  CryptHashData @hash, str, str.length, 0
		  self
		end
		def finish
		  outlen = [4].pack("L")
		  len  = pInt do |here| CryptGetHashParam @hash, HP_HASHSIZE, here, outlen, 0 end
		  data = "\0"*len
		  CryptGetHashParam @hash, HP_HASHVAL, data, [len].pack("L"), 0   
		  CryptDestroyHash @hash
		  close
		  data.unpack("H*").first
		end
		
		def close
		  CryptReleaseContext @context, 0
		end   
	  end
	  
	  def md5(str)
	    CryptContext.new.setupencrypt(:md5).push(str).finish
	  end
	  
	  def sha1(str)
	    CryptContext.new.setupencrypt(:sha1).push(str).finish
	  end
	  
	  def random_bytes(n)
	    a = CryptContext.new
		a.random_bytes(n)
      ensure
	    a.close
	  end
	end
	
	include Crypt
    #
    #
    #  ? / 30 Port
    #
    #
    #  A port basically has four operations like a binary file:
    #  connect, read, write ,close
    # 
    module BasicPort
        def read(*a)
           @io.read(*a)
        end
        def write(*a)
           @io.write(*a)
        end
        def connect(*a)
            @io.connect(*a)
        end
        def close(*a)
            @io.close(*a)
        end
        def initialize(io)
            @io = io
        end
       def to_io
            self
        end
        def method_missing(sym, *args)
           return @io.send(sym, *args) if @io
           super
        end
    end
    class Port
        include BasicPort
        def reconnect
           @io.close
           @io.connect
        end
        def getbyte
          if(v = @io.read(1))
             v.unpack("C").first
          else
             nil
          end
        end

        def printf(*args)
           write sprintf(*args)
        end
        def puts(*args)
	args.each{|i|  if Array === i then puts(i) else write i; write "\n"; end }
        end
    end

    class BufferedReadPort
        include BasicPort
        def _buffer
           @_buffer ||= ""
        end
        alias basicread read
        def getbyte
            @io.getbyte
        end
        def peek(n)
            if _buffer.size < n
               if !(v = basicread(n - _buffer.size))
                  return _buffer.size > 0 ? _buffer[0..-1] : nil
               else
                  _buffer << v
               end
            end
            _buffer[0, n]
        end

        def read(n)
            if _buffer.size < n
               if !(v = basicread(n - _buffer.size))
                  return _buffer.size > 0 ? _buffer.slice!(0..-1) : nil
               else
                  _buffer << v
               end
            end
            _buffer.slice!(0, n)

        end
        def eos?
            peek(1) == nil
        end
        def rest?
            !eos?
        end
    end

     class LogPort
        include BasicPort
        def call(name, a)
           write "[#{name}] #{Time.now} #{a}\n"
        end
        def info(a)
          call :info, a
        end
        def warning(a)
          call :warning, a
        end
        def error(a)
          call :error, a
        end
        def debug(a)
          call :debug, a 
        end
     end

     FilePort = File
	 
     class UDPPort
        extend Seiran30
        declapi 'ws2_32', 'socket', 'recvfrom', 'sendto', 'closesocket'
        def initialize(uri = "udp://127.0.0.1:8080")
           if uri =~ /udp:\/\/(\d+\.\d+\.\d+\.\d+):(\d+)/
              @host = $1.split(".").map{|x| x.to_i}
              @port = $2.to_i
              @addr = [2, @port, *@host].pack("snCCCCx8")
           else
              raise_with_class "Unknown uri #{uri}"
           end
        end
        def connect
             @socket = socket(2, 2, 0)
        end
        def close
             closesocket @socket
        end
        def read(n)
           buf = "\0"*n
           recvfrom @socket, buf, n, 0, "\0"*16, 16
           buf
        end
        def write(str)
           sendto @socket, str, str.length, 0, @addr, @addr.size
        end
   end 

   class TCPPort
	extend Seiran30
	declapi 'ws2_32', 'socket', 'recv', 'send', 'closesocket', 'connect'
	ARECV = API.new('ws2_32', 'recv').async
	ASEND = API.new('ws2_32', 'send').async
        
        def initialize(uri = "tcp://127.0.0.1:8080")
           if uri =~ /tcp:\/\/(\d+\.\d+\.\d+\.\d+):(\d+)/
              @host = $1.split(".").map{|x| x.to_i}
              @port = $2.to_i
              @addr = [2, @port, *@host].pack("snCCCCx8")
           else
              raise_with_class "Unknown uri #{uri}"
           end
        end
       alias  socket_connect connect
        def connect
             @socket = socket(2, 1, 6)
	     socket_connect @socket, @addr, @addr.size
        end
        def close
             closesocket @socket
       end
       def begin_read(n, buf = "\0"*n)
	     ARECV.call(@socket, buf, n, 0).done{|t, env| env[:value] = buf}
       end
       def begin_write(str)
	     ASEND.call(@socket, str, str.length, 0)
       end
	
        def read(n)
           buf = "\0"*n
           recv @socket, buf, n, 0
           buf
        end
        def write(str)
           send @socket, str, str.length, 0
        end
   end
   
  #
  #  Smart builders
  #
  class ClassBuilder
	def initialize(data = {})
		update data
	end
	
	def const_text(name, value)
		"#{name} = #{value}\n"
	end
	
	def method_text(name, args, content)
		"def #{name}(#{args.join(",")})\n"   \
		"	#{content}\n" 				   \
		"end\n"
	end
	
	def api_text(dll, func)
		"defapi #{dll.to_s.inspect}, #{func.to_s.inspect}\n"
	end
	
	def update(data = {})		
		self.data.update data
		update_text
		update_class
	end
	
	def data
		@data ||= {}
	end
	
	def buildee
		@class ||= Module.new
	end
	
	alias result buildee
	
	
	def new(*a, &b)
		buildee.new(*a, &b)
	end
	
	def update_class
		buildee.class_eval @text
	end
	
	def update_text
		@text = ""
		data = self.data
		data.each{|key, val|
			case key
				when :class
					if @base
						@class = val.new(@base)
					else
						@class = val.new
					end
				when :base
					if @base != val
						@class = Class.new(val)
						@base = val
					end
				when :api
					val.each{|k, v|
						v = Array(v)
						v.each{|x|
							@text << api_text(k, x)
					}
				}
				when :const
					val.each{|k, v|
						@text << const_text(k, v)
					}
				when :def
					val.each{|k, v|
						args = Array(v[:args])
						@text << method_text(k, args, v[:text])
					}
			end
		}
		
	end
     end


    module InitBehavior
	module InitCall
		def behave_init(block)
			block.call(self) if block
		end
	end
	module InitEval
		def behave_init(block)
			instance_eval0(&block) if block
		end
	end
    end

    class HashBuilder
	include InitBehavior::InitCall
	def initialize(data = {}, &block)
		@data = data
		behave_init block
	end
	def method_missing(sym, arg = nil, &b)
		@data[sym] = arg
		if b
			@data[sym] = self.class.new(&b).result
		end
		@data[sym]
	end
	def result
		@data
	end
end

   class HashBuilderI < HashBuilder
	include InitBehavior::InitEval
  end

   class ArrayBuilder
	include InitBehavior::InitCall
	def initialize(data = [], &block)
		@data = []
		behave_init block
	end
	def push(*a)
		a.each{|i| @data.push i}
	end
	def method_missing(*args, &b)
		if  b
			r = new_hash_i(&b)
		end
		@data.push (args + [r])
		
	end
	def result
		@data
	end
  end

  class ArrayBuilderI < ArrayBuilder
	include InitBehavior::InitEval
  end



   class ProcBuilder
	def initialize(data = {}, binding = TOPLEVEL_BINDING)
		@data = data
		@binding = binding
	end
	def result
		text = "lambda{| " << (@data[:args] || []).join(",")
		if @data[:locals]
			text << ";" << @data[:locals].join(",")
		end
		text << "|\n" << @data[:text] << "}"
		eval text, @binding
	end
   end
   
   class InvokeBuilder
	  def initialize(data = {}, &b)
	    @data = data	  
		@data[:proc] ||= b
	  end
	  def result
		 obj    = @data[:object]
		 sym    = @data[:symbol]   || :each
		 proc   = @data[:proc]
		 args   = @data[:args]      
		 retproc = @data[:retproc] || lambda{|o_, s_, a_, p_|        
		 	if proc
		    	 o_.send(s_, *a_, &p_)
	     	else
		    	 o_.send(s_, *a_)
		 	end
		 }.call(obj, sym, proc)
 	  end
   end
   
   
   
   class EnumBuilder
	  def initialize(data = {}, &b)
	    @data = data	  
		@data[:proc] ||= b
	  end
	  def result
		 ret_arr = []
		 obj    = @data[:object]
		 sym    = @data[:symbol]  || :each
		 args   = Array @data[:args]
		 withobject = @data[:with_object]
		 proc   = @data[:proc]    || lambda{|ret_arr, withobject| lambda{|o| ret_arr.push o} }
		 ret    = @data[:retproc] || lambda{|o_, s_, a_, p_, r_, w_|
			 _p  = p_.call(r_, w_)
			 val = o_.send(s_,*a_, &lambda{|*a| _p.call(*a)})
			 r_
		 }
		 ret.call(obj, sym, args, proc, ret_arr, withobject)
 	  end
   end
   
    class EnumBuilderScalar
	  def initialize(data = {}, &b)
	    @data = data	  
		@data[:proc] ||= b
	  end
	  def result
		 ret_arr    = []
		 obj        = @data[:object]
		 sym        = @data[:symbol]  || :each
		 args       = Array @data[:args]
		 withobject = @data[:with_object]
		 proc       = @data[:proc]    || lambda{|ret_arr, withobject| lambda{|o| ret_arr.push o} }
		 ret        = @data[:retproc] || lambda{|o_, s_, a_, p_, r_, w_|
			 _p  = p_.call(r_, w_)
			 o_.send(s_,*a_, &lambda{|*a| _p.call(*a)})
			 w_[0]
		 }
		 ret.call(obj, sym, args, proc, ret_arr, withobject)
 	  end
	   
	  
   end
    
   def new_class(*a, &b)
	ClassBuilder.new(*a, &b).result
   end
 
   def new_hash(*a,  &b)
	HashBuilder.new(*a, &b).result
   end

   def new_hash_i(*a, &b)
	HashBuilderI.new(*a, &b).result   
  end

   def new_array(*a, &b)
	ArrayBuilder.new(*a, &b).result   
  end

  def new_array_i(*a, &b)
	ArrayBuilderI.new(*a, &b).result   
   end
  
   def new_invoke(*a, &b)
	  InvokeBuilder.new(*a, &b).result
   end
   
   def new_map(*a, &b)
	  EnumBuilder.new(*a) do |ret_arr|
		 lambda{|o|
		 	ret_arr.push b.call(o)
		 } 
	  end
   end
   
   def new_enum(*a, &b)
	  EnumBuilder.new(*a, &b) 
   end
   
   def new_reduce(opt = {}, &b)
	   if opt.include?(:init)
		   init = opt[:init]
		   arr  = opt[:object]
	   else
	       arr  = opt[:object][1..-1]
		   init = opt[:object][0]
	   end
	   init = [init]
	   r = opt.merge({:object => arr, :with_object => init})
	   EnumBuilderScalar.new(r) do |ret_arr, init|
		  lambda{|o|
		    init[0] = b.call(init.first, o) 
		  }
	   end
   end
   
   def new_proc(hash = {}, binding = nil,  &b)
	binding ||= b.binding if b
	binding ||= TOPLEVEL_BINDING
	ProcBuilder.new(hash, binding, &b).result   
   end

   def ScopeBuilder(name)
	{:class => Module,
	 :const => {:Scope => []},
	 :def =>{
		:initialize   => {:args => [], :text => "@data = {}"},
		:[]            =>  {:args => ["*args"], :text=>"@data.[](*args)"},
		:[]=          =>  {:args => ["*args"], :text=>"@data.[]=(*args)"},
		:enter       => {:args=>[], :text=>"#{name}::Scope.push(self)"},
		:leave       => {:args=>[], :text=>"#{name}::Scope.pop"},
		"self.top" => {:args => [], :text=>"#{name}::Scope.last"},
		},
	}
   end
   
   ImportModule = ClassBuilder.new(ScopeBuilder("ImportModule")).result
   module ImportModule
	PATH = ["."]
	MODULES = {}
        DATA = {}
	attr_accessor :name
	def self.findfile(name)
		return name if DATA[name]
		name = name.tr(".", "/")
		return name if DATA[name]
		PATH.each{|k|
			r = File.join(k, name)
			return r if FileTest.file?(r)
			r = File.join(k, name + ".rb")
			return r if FileTest.file?(r)
		}
		raise "Can't find the file #{name}"
	end

	def self.readfile(name)
		DATA[name] || File.read(name)
        end
   end

   def export
	ImportModule::top
   end

   def req(file, importer = ImportModule.method(:readfile), find = ImportModule.method(:findfile))
	ImportModule::MODULES[file] ||= begin
		x = Module.new
		x.extend ImportModule
		x.name = file
		ImportModule::MODULES[file] = x
		x.enter
		unified_eval importer.call(find.call(file)), TOPLEVEL_BINDING, file, 1	
		x
	ensure
		x.leave
	end
   end


   #RPG Maker Only
   module Packaged
     module_function
     def read_data(name)
         y = class << Marshal; self; end
         y.send(:alias_method, :_old_load, :load)
         y.send(:define_method, :load){|a, *b| a.respond_to?(:read) ? a.read : a.to_s}
         ret = load_data(name)
         y.send(:alias_method, :load, :_old_load)
         ret
     end
   end
   
   def unified_func_nullary(a = nil, bd = TOPLEVEL_BINDING, file = "<unified_eval>", line = 1, &c)
	  r = a || c
	  case r
		when String
		   ruby_syntax_check r
		   eval r, bd, file, line
		when Proc
		   r.call
	  end
   end
  alias unified_eval unified_func_nullary

  def data_req(file, str = nil, &b)
	ImportModule::DATA[file] = str || b
  end
   
  #===ttlang
  class TTLang
  Node = Struct.new(:text, :indent, :sub, :parent)
  class Node
    def inspect
      "(#{text} #{(sub || [:nil]).map(&:inspect).join(' ')} )"
    end
    def data
       @data ||= {}
    end
  end
  attr_accessor :str, :lines, :result
  def initialize(str)
    @str = str
  end

  def parse
    @lines = @str.split("\n")
    @index = -1
    @result = Node.new("", -1, [], nil)
    @result.sub = node(-1, @result)
    @result.data[:virtual] = true
    @result
  end

  def eos?
    !(@index < @lines.size)
  end

  def peekeos?
    !(@index + 1 < @lines.size)
  end


  def indent_size(str)
    str[/\A\s*/].size
  end

  def text(str)
    str.sub(/\A\s*/, "")
  end

  def node(parent_indent = -1, parent = nil)
    result = []
    subindent = parent_indent
    while not peekeos?  
      subindent = indent_size(@lines[@index + 1])
      return result if subindent <= parent_indent
      @index += 1
      n = Node.new(text(@lines[@index]), subindent, nil, parent)
      n.sub = node(subindent, n)
      result << n
    end
    result
  end   

  def generate(obj = Generator.new)
     obj.call(@result, 0).join("\n")
  end

  class Generator
    INDENTSIZE = 4
    ENDWORD    = "end"
    def initialize
      @indent = {}
    end


    def make_indent(n)
       " "*(n * INDENTSIZE)
    end

    def deep_copy(a)
       Marshal.load(Marshal.dump(a))
    end

    def subst(obj, indent, subst = {})
       lines = []
       t = obj.text
       obj.indent = indent
       subst.each{|k, v|
          t = t.gsub(k, v)
       }
       unless obj.sub.empty?
         obj.sub.each{|x| subst(x, indent + 1, subst)}
       end
       obj.text = t
       obj
    end
    
    def code(obj, indent)
       sugars(indent).each{|k, v|
         if k =~ obj.text
           args     = argslist(obj.text.sub(k, ""))
           argnames = v[0]
            
           hash = {}
           argnames.map{|x| "\\\{#{x}\}"}.zip(args).each{|a| hash[a[0]] = a[1]}
           hash["\\{__id}"] = "__#{@__id = 0; @__id += 1}"
           node = Node.new("", indent,  deep_copy(v[1]), nil)
           node.data[:virtual] = true
           subst(node, indent, hash)
	   	   return self.class.new.call(node, indent)
         end
       }

       lines = []
       lines.push make_indent(indent) << obj.text unless obj.data[:virtual]
       unless obj.sub.empty?
          obj.sub.each{|x| lines.concat call(x, indent + 1)}
          lines.push make_indent(indent) << ENDWORD  unless obj.data[:virtual] || obj.data[:no_end]
       end


       lines
    end

    def sugars(indent)
       ret = {}
       @indent.keys.sort.each{|k|
            ret.update @indent[k][:sugar] if @indent[k][:sugar]
       }
       ret
    end

    def argslist(args)
       u = []
       args.scan(/(("([^"]|"")*")|\S+|([,\+\-\*\/;=-]\s*))/) do |z| u << z.flatten[0] end
       u
    end

    def defsugar(indent, name, args, block)
       @indent[indent]         ||= {}
       @indent[indent][:sugar] ||= {}
       @indent[indent][:sugar][/^#{name}/] = [argslist(args), block]
       []
    end

    def clear(indent)
       @indent.keys.each{|x|@indent[x] = {} if x > indent}
    end

    def call(obj, indent = 0)
       clear indent
       case obj.text
         when /\Adefsugar ([\S]*?) (.*)/
           defsugar indent, $1, $2, obj.sub
         when /\Aelse/, /\Aelsif/
           obj.data[:no_end] = true
           code(obj, indent - 1)
         when /.*/
           code(obj, indent)
         else
           []
       end
    end
	
	def hanss?(obj, s = {})
		s[obj] ||= begin
			s[obj] = true 
		    case obj
			  when Numeric, String, Symbol then true
			  when Hash then
			  	obj.keys.all?{|x| hanss?(x, s)} && obj.values.all?{|x| hanss?(x, s)}
			  when Array then
			  	obj.all?{|x| hanss?(x, s)}
			  else
			  	false
		    end
		end
	end
	

  end

 end


  def ttlang(str, obj = TTLang::Generator.new)
    node = TTLang.new(str)
    node.parse
    node.generate(obj)
  end


end 



