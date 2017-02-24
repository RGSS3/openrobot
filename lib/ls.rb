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

  def self.set fn, keys, value
    return -1 if fn.empty?
    return -2 if keys.empty?
    file = self.new fn
    key  = keys.clone.shift
    if keys.empty?
      file[key] = value
    else
      cont = file[key] || {}
      cont = {} unless cont.is_a? Hash
      keys.each_with_index.inject cont do |h, (k, i)|
        if i == keys.size - 1
          h[k] = value
        else
          h[k] = {} unless h[k].is_a? Hash
        end
      end
      file[key] = cont
    end
    return 0
  end

  def self.get fn, keys
    file = self.new fn
    key  = keys.clone.shift
    if keys.empty?
      file[key]
    else
      file[key].dig *keys rescue nil
    end
  end
end
