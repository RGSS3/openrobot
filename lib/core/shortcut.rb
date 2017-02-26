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

def R(*args, &block)
  OpenRobot.register *args, &block
end