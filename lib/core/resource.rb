module Resource
  Table = SQLite3::Database.new('database/resource.db')
  def self.find_by_name(name)
    (Table.execute("select id from resource where name = ?", name) || []).flatten[0]
  end

  def self.find_name_by_id(id)
    (Table.execute("select name from resource where id = ?", id) || []).flatten[0]
  end

  def self.alter(id, user_id, amount = nil)
    if !Table.execute("select * from user_resource where rsrcid=? and userid=?", id, user_id).empty?
       if amount 
         Table.execute "update user_resource set amount = amount + ? where rsrcid = ? and userid = ?", amount, id, user_id
       end
    else
      Table.execute "insert into user_resource (userid, rsrcid, amount, expire_at) values (?, ?, ?, ?)", user_id, id, amount, nil
    end        
  end

  def self.get(id, user_id)
    (Table.execute("select amount from user_resource where rsrcid=? and userid=?", id, user_id) || []).flatten[0]
  end

  def self.coupon_used?(user_id, coupon_id)
    Table.execute("select used_at amount from user_coupon where id = ? and user_id = ?", coupon_id, user_id).flatten[0]
  end

  def self.find_coupon_by_code(code)
    Table.execute("select id from coupon where code = ?", code).flatten[0]
  end

  def self.use_coupon(user_id, coupon_str)
    id = find_coupon_by_code coupon_str
    raise "Error 110: no such coupon" if !id
    used_at =  coupon_used?(user_id, id)
    raise "Error 111: used coupon at #{Time.at(used_at)}" if used_at
    r = Table.execute("select id, rsrcid, amount from coupon where code = ? and ifnull(used_at, 2147483647) > ? and stock > 0", coupon_str, Time.now.to_i)
    if !r.empty?
      Table.execute("update coupon set stock = stock - 1 where id = ?", r[0][0])
      Table.execute("insert into user_coupon (id, user_id, used_at) values (?, ?, ?)", id, user_id, Time.now.to_i)
      self.alter(r[0][1], user_id,  r[0][2])
      true
    else
      false
    end
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