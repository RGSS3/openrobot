class LocalStorage
  def initialize(fn)
     @fn = fn
  end

  def [](*args)
     @hash = Marshal.load(IO.binread(@fn)) rescue {}
     @hash.[] *args
  end 

  def []=(*args)
     @hash = Marshal.load(IO.binread(@fn)) rescue {}
     @hash.[]= *args
     IO.binwrite @fn, Marshal.dump(@hash)
  end
end