=begin #(fold)
++
Copyright 2004-2007 Joyent Inc.

Redistribution and/or modification of this code is 
governed by the GPLv2.

Report issues and contribute at http://dev.joyent.com/

$Id$
--
=end #(end)

class MessageUidToInteger < ActiveRecord::Migration
  def self.up
    remove_column :messages, :uid
    add_column    :messages, :uid, :integer
  end

  def self.down
    remove_column :messages, :uid
    add_column    :messages, :uid, :string
  end
end
