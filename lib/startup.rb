Perm = Privilege
require 'tempfile'
require 'json'
require 'rqrcode'
class Fiber
  alias call resume
end

class Enumerator
  def call(*args, **kwargs)
    self.next
  end
end

