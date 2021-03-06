=begin #(fold)
++
Copyright 2004-2007 Joyent Inc.

Redistribution and/or modification of this code is 
governed by the GPLv2.

Report issues and contribute at http://dev.joyent.com/

$Id$
--
=end #(end)

class CreateCommentings < ActiveRecord::Migration
  def self.up
    create_table :commentings do |t|
      t.column :comment_id,       :integer
      t.column :commentable_id,   :integer
      t.column :commentable_type, :string
    end
  end

  def self.down
    drop_table :commentings
  end
end
