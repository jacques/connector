class NotesVersionedTables < ActiveRecord::Migration
  def self.up
    Note.create_versioned_table
  end

  def self.down
    Note.drop_versioned_table
  end
end
