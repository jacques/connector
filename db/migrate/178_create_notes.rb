class CreateNotes < ActiveRecord::Migration
  def self.up
    create_table :notes do |t|
      t.column :organization_id, :integer
      t.column :user_id, :integer
      t.column :name, :string
      t.column :body, :text
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
      t.column :note_folder_id, :integer
    end
  end

  def self.down
    drop_table :notes
  end
end
