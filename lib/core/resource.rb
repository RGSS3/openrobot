module Resource
  Table = SQLite3::Database.new('database/resource.db')
  def self.find_by_name(name)
    (Table.execute("select id from resource where name = ?", name) || []).flatten[0]
  end

  def self.find_name_by_id(id)
    (Table.execute("select name from resource where id = ?", id) || []).flatten[0]
  end

  def self.shrink(id, user_id)
     a = Table.execute("select amount,  operate_at from user_resource where rsrcid=? and userid=?", id, user_id)[0] || []
    (amount, operate_at)  = a
    ((capacity, regen),) = Table.execute("select capacity, regen from resource where id = ?", id)
    if !operate_at
      if (capacity || 0) > 0
        if !Table.execute("select * from user_resource where rsrcid=? and userid=?", id, user_id).empty?
          Table.execute "update user_resource set amount = ?, operate_at = ? where rsrcid=? and userid=?", capacity, Time.now.to_i, id, user_id
        else
          Table.execute "insert into user_resource (userid, rsrcid, amount, expire_at, operate_at) values (?, ?, ?, ?, ?)", user_id, id, capacity, nil, Time.now.to_i
        end
        return 
      end
    end
    if (regen || 0) > 0
      tm = (Time.now.to_i - operate_at) / 60
      add = tm * regen
      if add > 0
        if (amount || 0) < capacity
          value = (amount || 0) + add
          value = [value, capacity].min if capacity
          Table.execute "update user_resource set amount = ?, operate_at = ? where rsrcid=? and userid=?", value, operate_at + tm * 60, id, user_id
        end
      end
    end
  end

  def self.alter(id, user_id, amount = nil)
    self.shrink(id, user_id)
    if !Table.execute("select * from user_resource where rsrcid=? and userid=?", id, user_id).empty?
       if amount 
         Table.execute "update user_resource set amount = amount + ? where rsrcid = ? and userid = ?", amount, id, user_id
       end
    else
      Table.execute "insert into user_resource (userid, rsrcid, amount, expire_at) values (?, ?, ?, ?)", user_id, id, amount, nil
    end        
  end

  def self.all_bounded_code(user_id)
    Table.execute "select rsrcid, amount, code from coupon C where user_id = ? and ifnull(invite_id, -1) = -1 and C.id not in (select id from user_coupon where user_id = C.user_id)", user_id
  end

  def self.get(id, user_id)
    self.shrink(id, user_id)
    (Table.execute("select amount from user_resource where rsrcid=? and userid=?", id, user_id) || []).flatten[0]
  end

  def self.coupon_used?(user_id, coupon_id)
    Table.execute("select used_at amount from user_coupon where id = ? and user_id = ?", coupon_id, user_id).flatten[0]
  end

  def self.coupon_info(coupon_str)
    Table.execute("select rsrcid, amount from coupon where code = ?", coupon_str)[0]
  end

  def self.find_coupon_by_code(code)
    Table.execute("select id from coupon where code = ?", code).flatten
  end

  def self.use_coupon(user_id, coupon_str)
    id = find_coupon_by_code coupon_str
    raise "Error 110: no such coupon" if !id
    used_at =  coupon_used?(user_id, id)
    raise "Error 111: used coupon at #{Time.at(used_at)}" if used_at
    r = Table.execute("select id, rsrcid, amount, user_id, invite_id from coupon where code = ? and ifnull(used_at, 2147483647) > ? and stock > 0", coupon_str, Time.now.to_i)
    if !r.empty?
      return false if r[0][3] && (r[0][3] != user_id && r[0][4] == nil || r[0][3] == user_id && r[0][3] == r[0][4])
      Table.execute("update coupon set stock = stock - 1 where id = ?", r[0][0])
      Table.execute("insert into user_coupon (id, user_id, used_at) values (?, ?, ?)", id, user_id, Time.now.to_i)
      self.alter(r[0][1], user_id,  r[0][2])
      if r[0][4]
        self.alter(r[0][1], r[0][4],  (r[0][2] + 4) / 5)
      end
      true
    else
      false
    end
  end
  require 'digest/md5'
  def self.gen_coupon(rsrcid, amount, stock = 1, prefix = "", user_id = nil, invite_id = nil)
    name = prefix + Time.now.to_i.to_s(16).rjust(8, '0A').upcase + Digest::MD5.hexdigest(Random.new.bytes(64)).upcase
    Table.execute "insert into coupon (name, code, used_at, rsrcid, amount, stock, user_id, invite_id) values (?, ?, ?, ?, ?, ?, ?, ?)", name, name, nil, rsrcid, amount, stock, user_id, invite_id
    name
  rescue
    $!.backtrace.unshift($!.to_s)
  end
  ResourceModule = self

  class Resource
    attr_accessor :id
    def initialize(id_or_name)
      case id_or_name
      when String
        self.id = ResourceModule.find_by_name(id_or_name)
      when Integer
        self.id = id_or_name
      when Resource
        self.id = id_or_name.id
      end
    end

    def name
      ResourceModule.find_name_by_id(self.id)
    end

    def get(user_id)
      ResourceModule.get(self.id, user_id) || 0
    end

    def gain(user_id, amount)
      ResourceModule.alter(self.id, user_id, amount)
      true
    rescue
      false
    end
  end
end