class LocalStorage
  def initialize(fn)
     @fn = "ls/#{fn}"
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
<<<<<<< HEAD

  def self.set fn, keys, value
    return -1 if fn.empty?
    return -2 if keys.empty?
    file = self.new fn
    key  = keys.shift
    if keys.empty?
      file[key] = value
    else
      cont = file[key] || {}
      keys.each_with_index.inject cont do |h, (k, i)|
        h[k] = value if i == keys.size - 1
        h[k] ||= {}
      end
      file[key] = cont
    end
    return 0
  end

  def self.get fn, keys
    file = self.new fn
    key  = keys.shift
    if keys.empty?
      file[key]
    else
      file[key].dig *keys
    end
  end
=======
>>>>>>> fafcd075f01dd5d75dcb19146851fcc28cfd7e5f
end
