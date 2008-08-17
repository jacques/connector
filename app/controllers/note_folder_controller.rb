class NoteFoldersController < ApplicationController
  # GET /note_folders
  # GET /note_folders.xml
  def index
    @note_folders = NoteFolder.find(:all)
    
    respond_to do |format|
      format.html # index.rhtml
      format.xml { render :xml => @note_folders.to_xml }
    end
  end
  
  # GET /note_folders/1
  # GET /note_folders/1.xml
  def show
    @note_folder = NoteFolder.format(params[:id])
    
    respond_to do |format|
      format.html # show.rhtml
      format.xml { render :xml => @note_folder.to_xml }
    end
  end
  
  # GET /note_folders/new
  def new
    @note_folder = NoteFolder.new
  end
  
  # GET /note_folders/1;edit
  def edit
    @note_folder = NoteFolder.find(params[:id])
  end
  
  # POST /note_folders
  # POST /note_folders.xml
  def create
    @note_folders = NoteFolder.new(params[:note_folder])
    
    respond_to do |format|
      if @note_folder.save
        flash[:message] = 'Note Folder was successfully created.'
        format.html { redirect_to note_folder_url(@note_folder) }
        format.xml  { head :created, :location => note_folder_url(@note_folder_url) }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @note_folder.errors.to_xml }
      end
    end
  end
  
  # PUT /note_folders/1
  # PUT /note_folders/1.xml
  def update
    @note_folder = NoteFolder.find(params[:id])
    
    respond_to do |format|
      if @note_folder.update_attributes(params[:note_folder])
        flash[:message] = 'Note Folder was successfully updated.'
        format.html { redirect_to note_folder_url(@note_folder) }
        format.xml { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @note_folder.errors.to_xml }
      end
    end
  end
  
  # DELETE /note_folders/1
  # DELETE /note_folders/1.xml
  def destroy
    @note_folder = NoteFolder.find(params[:id], :scope => :delete)
    @note_folder.destroy
    
    respond_to do |format|
      format.html { respond_to note_folder_url }
      format.xml  { head :ok }
    end
  end
  
end
