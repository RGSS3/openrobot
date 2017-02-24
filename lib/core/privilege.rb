
module Privilege
  Entity   = SQLite3::Database.new('database/entity.db')
  Relation = SQLite3::Database.new('database/relation.db')
  Error    = Class.new Exception

  def self.user_has_privilege(user_id, priv)
    priv_id = find_priv_id(priv)
    if !priv_id          
      return false
    end
    find_user_all_priv(user_id).include?(priv_id)
  end

  def self.find_user_group(user_id)
    Relation.execute("select group_id from user_group where user_id = ?", user_id).flatten
  end

  def self.find_group_id(group_name)
    (Entity.execute("select id from usergroup where name = ?", group_name) || []).flatten[0]
  end
  def self.find_priv_id(priv)
    (Entity.execute("select id from privilege where name = ?", priv) || []).flatten[0]
  end

  def self.add_user(user_id, group)
    group_id = find_group_id group
    if !group_id
       raise Error, "Error 105: no such group #{group}"
    end
    Relation.execute "insert into user_group values (?, ?)", user_id, group_id
  end

  def self.remove_user(user_id, group)
    group_id = find_group_id group
    if !group_id
       raise Error, "Error 105: no such group #{group}"
    end
    Relation.execute "delete from user_group where user_id = ? and group_id = ?", user_id, group_id
  end

  def self.allow_user(user_id, priv)
    priv_id = find_priv_id(priv)
    if !priv_id
       raise Error, "Error 106: no such permission #{priv}"
    end
    Relation.execute "insert into user_privilege values (?, ?)", user_id, priv_id
  end

  
 def self.deny_user(user_id, priv)
    priv_id = find_priv_id(priv)
    if !priv_id
      raise Error, "Error 106: no such permission #{priv}"
    end
    Relation.execute "delete from user_privilege where user_id = ? and privilege_id = ?", user_id, priv_id
  end


 def self.allow_group(group, priv)
    group_id = find_group_id group
    if !group_id
       raise Error, "Error 105: no such group #{group}"
    end
    priv_id = find_priv_id(priv)
    if !priv_id
       raise Error, "Error 106: no such permission #{priv}"
    end
    Relation.execute "insert into group_privilege values (?, ?)", group_id, priv_id
  end

 def self.deny_group(group, priv)
    group_id = find_group_id group
    if !group_id
       raise Error, "Error 105: no such group #{group}"
    end
    priv_id = find_priv_id(priv)
    if !priv_id
       raise Error, "Error 106: no such permission #{priv}"
    end
    Relation.execute "delete from group_privilege where group_id = ? and privilege_id = ?", group_id, priv_id
  end

  def self.new_group(group)
    group_id = find_group_id group
    if group_id
       raise Error, "Error 107: such group #{group} exists"
    end
    Entity.execute "insert into usergroup values (NULL, ?)", group
  end

  def self.new_privilege(priv)
    priv_id = find_priv_id(priv)
    if priv_id
       raise Error, "Error 108: such permission #{priv} exists"
    end
    Entity.execute "insert into privilege values (NULL, ?)", priv
  end
  
  def self.find_group_priv(group_id)
    Relation.execute("select privilege_id from group_privilege where group_id = ?", group_id).flatten
  end

  def self.find_user_priv(user_id)
    Relation.execute("select privilege_id from user_privilege where user_id = ?", user_id).flatten
  end

  def self.find_user_all_priv(user_id)
    group_ids = find_user_group(user_id)
    (group_ids.flat_map{|x| find_group_priv(x)} + find_user_priv(user_id)).uniq.sort
  end
end