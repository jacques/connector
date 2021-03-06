=begin #(fold)
++
Copyright 2004-2007 Joyent Inc.

Redistribution and/or modification of this code is 
governed by the GPLv2.

Report issues and contribute at http://dev.joyent.com/

$Id$
--
=end #(end)

class AddStrongspaceReportDescriptions < ActiveRecord::Migration
  def self.up
    ReportDescription.create :name => 'files_strongspace' 
  end

  def self.down
    ReportDescription.find_by_name('files_strongspace').destroy
  end
end
