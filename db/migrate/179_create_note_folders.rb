class CreateNoteFolders < ActiveRecord::Migration
  def self.up
    create_table :note_folders do |t|
      t.column :user_id, :integer
      t.column :parent_id, :integer
      t.column :name, :string
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
    end
  end

  def self.down
    drop_table :note_folders
  end
end
