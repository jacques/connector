class Note < ActiveRecord::Base
  include JoyentItem
  acts_as_versioned
  
  belongs_to :note_folder
  
  validates_presence_of :note_folder_id
  validates_presence_of :name
  
  # so we can set what the current note is
  cattr_accessor :current
  
  # Differentiate this revision with a preceeding or following revision
  def Note::diff(note, with_revision)
    # Decide which revision is the older
    if note.version < with_revision.version
      old_version = note
      new_version = with_revision
    else
      old_version = with_revision
      new_version = note
    end
    
    alignment = Note::align(old_version, new_version)
    
    # count the number of insertions and deletions
    insertions = 0.0
    deletions = 0.0
    
    alignment[:old].each_index do |index|
      old_word = alignment[:old][index]
      new_word = alignment[:new][index]
      
      if old_word.nil? && new_word
        insertions = insertions + 1.0
      elsif old_word && new_word.nil?
        deletions = deletions + 1.0
      end
    end
    
    total = alignment[:old].length.to_f
    
    changes = {:insertions => (insertions/total*100).to_i, :deletions => (deletions/total*100).to_i,
               :alignment => alignment}
    
    return changes
  end
  
  # Produce an alignment between two texts using dynamic programming
  def Note::align(old_version, new_version)
    
    old_sequence = Note::split(old_version.body)
    new_sequence = Note::split(new_version.body)
    
    # build an array N × M matrix filled with 0 where
    # N = length of the old sequence + 1
    # M = length of the new sequence + 1
    n = old_sequence.length + 1
    m = new_sequence.length + 1
    alignment_scores = Array.new(n){|index| Array.new(m, 0)}
    
    old_sequence.each_index do |n|
      new_sequence.each_index do |m|
        old_word = old_sequence[n]
        new_word = new_sequence[m]
        
        s = Note::match_score(old_word, new_word) # match/mismatch score
        w = 0 # gap penelty
        alignment_scores[n+1][m+1] = [alignment_scores[n][m] + s,   # match/mismatch is the diagonal
                                      alignment_scores[n+1][m] + w, # gap in the new version (insertion)
                                      alignment_scores[n][m+1] + w  # gap in the old version (deletion)
                                     ].max
      end
    end
    
    # trace backwards to find optimal alignment
    old_alignment = Array.new
    new_alignment = Array.new
    
    # keep track of where we are in the matrix, starting at the final corner
    while (n >= 0 && m >= 0)
      current_score = (alignment_scores[n][m]     || -1) # score of the cell we are looking at
      insert_score  = (alignment_scores[n][m-1]   || -1) # score to the left, indicating an insertion
      delete_score  = (alignment_scores[n-1][m]   || -1) # score above us, indicating a deletion
      match_score   = (alignment_scores[n-1][m-1] || -1) # score diagonally, indicating  match or mismatch
      
      if m <= 0 
        insert_score = -1
        match_score = -1
      end
      
      if n <= 0
        delete_score
        match_score = -1
      end
      
      # puts "n: #{n} m: #{m}"
      #      puts "#{match_score} #{insert_score}\n#{delete_score} #{current_score}"
     
      max_score = [insert_score, delete_score, match_score].max

      case max_score
      when match_score # if they are all equal, prefer a match
        old_alignment << old_sequence[n] # add words from both sequences
        new_alignment << new_sequence[m]
        n = n - 1 # advance both counters
        m = m - 1
        #puts "match"
      when insert_score
        old_alignment << nil             # insert gap
        new_alignment << new_sequence[m] # insert word
        m = m - 1 # advance only the new sequence's counter
        #puts "insertion"
      when delete_score
        old_alignment << old_sequence[n] # insert word
        new_alignment << nil             # insert gap
        #puts "deletion"
        n = n - 1 # advance only the old sequence's counter
      end
      
      # puts "old: #{old_alignment.reverse.inspect}"
      #      puts "new: #{new_alignment.reverse.inspect}"
      #      
      #      name = gets
    end
    
  
    old_alignment.reverse!
    new_alignment.reverse!
    
    return {:old => old_alignment, :new => new_alignment}
  end
  
  # Split text into words and long words into characters
  def Note::split(text)
    text.split(/\b|\s/).map do |word|
      if word.length > 20
        word.split(//)
      else
        word
      end
    end.flatten.reject {|item| item =~ /\s+/ || item.empty?}
  end
  
  # determine a score for the alignment of two words
  def Note::match_score(old_word, new_word)
    if old_word == new_word
      return 1
    else
      return 0
    end
  end
end