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

  def delete key
    @hash = Marshal.load(IO.binread(@fn)) rescue {}
    @hash.delete key
    IO.binwrite @fn, Marshal.dump(@hash)
  end

  def self.set fn, keys, value
    return -1 if fn.empty?
    return -2 if keys.empty?
    file = self.new fn
    key  = keys.clone.shift
    if keys.empty?
      if value.nil?
        file.delete key
      else
        file[key] = value
      end
    else
      cont = file[key] || {}
      cont = {} unless cont.is_a? Hash
      keys.each_with_index.inject cont do |h, (k, i)|
        if i == keys.size - 1
          if value.nil?
            h[k].delete k
          else
            h[k] = value
          end
        else
          h[k] = {} unless h[k].is_a? Hash
        end
        h[k]
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
