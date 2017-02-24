Perm = Privilege
class Fiber
  alias call resume
end

class Enumerator
  def call(*args, **kwargs)
    self.next
  end
end

