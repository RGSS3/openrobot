O   = OpenRobot
OC  = O::Command
OCR = O::Command::Request
P   = Privilege
PE  = P::Entity
PR  = P::Relation

S   = O::Store
def S(*args)
  S.new(*args)
end

def R(*args, &block)
  OpenRobot.register *args, &block
end