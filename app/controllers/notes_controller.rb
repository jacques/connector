class NotesController < AuthenticatedController
  # load the default_sort_order
  before_filter :load_sort_order, :only => [:index]
  # REST
  
  # GET /notes
  # GET /notes.xml
  
  def index
    @view_kind = 'note'
    
    @toolbar[:new] = true
    @toolbar[:copy] = true
    @toolbar[:move] = true
    @toolbar[:delete] = true
    
    if params[:group] =~ /^\d+$/
      index_note_folder
    elsif params[:group] =~ /^s(\d+)$/
      index_smart_group
    else
      redirect_to notes_home_url and return
    end
    
    respond_to do |format|
      format.html # index.rhtml
      format.xml { render :xml => @notes.to_xml }
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to notes_home_url
  end
  
  # GET /notes/1
  # GET /notes/1.xml
  # GET /notes/1.txt
  
  def show
    @note = Note.find(params[:id], :scope => :read)
    
    Note.current = @note
    
    # 
    unless params[:revision].nil?
      @revision = @note.find_version(params[:revision])
    end
    
    if @revision.nil?
      @revision = @note
    end
    
    self.selected_user = @note.owner
    @note_folder = @note.note_folder
    @group_name = @note_folder.name
    
    @toolbar[:new] = true
    if @note == @revision
      @toolbar[:edit] = true
    else
      @toolbar[:revert] = true
    end
    @toolbar[:revisions] = true
    unless @revision == @note
      @toolbar[:show_current] = true
    end
    @toolbar[:text] = true
    
    respond_to do |format|
      format.html # show.rhtml
      format.js do
        render :update do |page|
          page[params[:update_id]].replace_html :partial => 'peek'
        end
      end
      format.xml { render :xml => @revision.to_xml }
      format.text { render :text => @revision.body}
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to notes_home_url
  end
  
  # GET /notes/new
  def new
    @note = Note.new
    @note_folder = User.current.notes_note_folder
    
    @toolbar[:new] = true
    @toolbar[:syntax] = true
  end
  
  # GET /notes/1;edit
  def edit
    @note = Note.find(params[:id], :scope => :edit)
    Note.current = @note
    
    unless params[:revision].nil?
      @revision = @note.find_version(params[:revision])
      unless @revision.nil?
        # update note's fields from the specified revision
        # doesn't change database, just what appears in the edit form
        @note.body = @revision.body
        @note.name = @revision.name
      end
    end
    
    self.selected_user = @note.owner
    @note_folder = @note.note_folder
    @group_name = @note_folder.name
    
    @toolbar[:new] = true
    @toolbar[:syntax] = true
    
    respond_to do |format|
      format.html { render :action => 'edit'}
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to note_url(params[:id])
  end
  
  # POST /notes
  # POST /notes.xml
  def create
    note_params = params[:note].merge(:organization_id => User.current.organization.id, :user_id => User.current.id)
    @note = Note.new(note_params)
    respond_to do |format|
      if @note.save
        flash[:message] = 'Note was successfully created.'
        format.html { redirect_to note_url(@note) }
        format.xml  { head :created, :location => note_url(@note) }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @note.errors.to_xml }
      end
    end
  end
  
  # PUT /notes/1
  # PUT /notes/1.xml
  def update
    @note = Note.find(params[:id], :scope => :edit)
    
    respond_to do |format|
      if @note.update_attributes(params[:note])
        format.html { redirect_to note_url(@note) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @note.errors.to_xml }
      end
    end
  end
  
  # DELETE /notes/1
  # DELETE /notes/1.xml
  def destroy
    @note = Note.find(params[:id], :scope => :delete)
    @note.destroy
    
    respond_to do |format|
      format.html { redirect_to notes_url }
      format.xml  { head :ok }
    end
  end
  
  # NON-REST
  def diff
     @note = Note.find(params[:id], :scope => :read)

      Note.current = @note

      # Find versions based on query parameters. 
      # Set to current version if not found
      unless params[:revision].nil?
        @revision = @note.find_version(params[:revision])
      end
      
      unless params[:with].nil?
        @with = @note.find_version(params[:with])
      end
        
      if @revision.nil?
        @revision = @note
      end
      
      if @with.nil?
        @with = @note
      end
      
      if @revision.version < @with.version
        @old_version = @revision
        @new_version = @with
      else
        @old_version = @with
        @new_version = @revision
      end
        
      old_version_as_html = Maruku.new(@old_version.body).to_html
      new_version_as_html = Maruku.new(@new_version.body).to_html
      @diff = HTMLDiff::DiffBuilder.new(old_version_as_html, new_version_as_html).build

      self.selected_user = @note.owner
      @note_folder = @note.note_folder
      @group_name = @note_folder.name

      @toolbar[:new] = true
      @toolbar[:revisions] = true
      @toolbar[:show] = true
      unless @revision == @note
        @toolbar[:show_current] = true
      end

      respond_to do |format|
        format.html # diff.rhtml
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to notes_home_url
  end
  
  def current_group_id
    if     @smart_group   then @smart_group.url_id
    elsif @note_folder    then @note_folder.id
    elsif @group_name     then @group_name
    else  nil
    end
  end
  
  def self.group_name
    'NoteFolder'
  end
  
  def item_class_name
    'Note'
  end
  
  protected
  
    def index_note_folder
      @note_folder = NoteFolder.find(params[:group], :scope => :read)
      self.selected_user = @note_folder.owner
      @group_name   = @note_folder.name
      @paginator    = Paginator.new self, @note_folder.notes.count, JoyentConfig.page_limit, params[:page]
      
      @notes = Note.find(:all,
                         :conditions => ["note_folder_id = ?", @note_folder.id],
                         :order => "notes.#{@sort_field} #{@sort_order}",
                         :limit => @paginator.items_per_page,
                         :offset => @paginator.current.offset,
                         :scope => :read)
    end
  
    def index_smart_group
      @smart_group = SmartGroup.find(SmartGroup.params_to_id(params[:group]), :scope => :read)
      self.selected_user = @smart_group.owner
      @group_name = @smart_group.name
    
      @paginator = Paginator.new self, @smart_group.items.size, JoyentConfig.page_limit, params[:page]
      @notes    = @smart_group.items(nil, @paginator.items_per_page, @paginator.current.offset).sort_by(&@sort_field.to_sym)
      @notes.reverse! if @sort_order == 'DESC'
    end
  
  private
  
    def valid_sort_fields
      ['name', 'updated_at']
    end
    
    def default_sort_field
      'name'
    end
    
    def default_sort_order
      'ASC'
    end
end
