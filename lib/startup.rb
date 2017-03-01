Perm = Privilege
require 'tempfile'
require 'json'
require 'rqrcode'
ENV['path'] += ";C:\\curl"
class Fiber
  alias call resume
end

class Enumerator
  def call(*args, **kwargs)
    self.next
  end
end

