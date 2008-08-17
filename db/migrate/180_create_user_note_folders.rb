class CreateUserNoteFolders < ActiveRecord::Migration
  def self.up
    add_column :note_folders, :organization_id, :integer
    
    Organization.find(:all).each do |organization|
      organization.users_and_admins.each do |user|
        if user.note_folders.select{|nf| nf.parent_id == nil}.blank?
          user.note_folders.create(:name => "Notes", :parent_id => nil, :organization_id => user.organization_id)
        end
      end
    end
  end

  def self.down
    remove_column :note_folders, :organization_id
  end
end
