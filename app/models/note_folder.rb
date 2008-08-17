class NoteFolder < ActiveRecord::Base
  include JoyentGroup
  
  validates_presence_of :name
  
  has_many :notes, :dependent => :destroy
  
  acts_as_tree :order => 'LOWER(note_folders.name)'
  
  
  
end