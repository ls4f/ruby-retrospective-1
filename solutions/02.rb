require 'set'

class Song
  attr_reader :genre, :subgenre, :artist, :name, :tags
  def initialize(song_string, extra_tags)
    @name, @artist, @genre, @tags = song_string.split('.').map(&:strip)
    @genre, @subgenre = @genre.split(',').map(&:strip)
    @tags = "#{@tags}".split(',').map(&:strip)
    @tags += ["#{@genre}".downcase, "#{@subgenre}".downcase]
    @tags = (@tags + extra_tags.fetch(@artist, []) - ['']).uniq
  end

  def ok_with_name(compare_with)
    @name == compare_with
  end

  def ok_with_artist(compare_with)
    @artist == compare_with
  end

  def ok_with_tags(compare_with)
    compare_with = [compare_with].flatten
    compare_with.all? do |tag| 
      tag.end_with?('!') != (@tags.include?tag.chomp('!'))
    end
  end
  
  def ok_with_filter(saint_lambda)
    saint_lambda.call self
  end
end

class Collection
  def initialize(songs_string, extra_tags)
    @songs = songs_string.lines.map { |line| Song.new(line, extra_tags) }
  end

  def find(criteria)
    @songs.select do |the_song| 
      criteria.all? { |field, value| the_song.send("ok_with_#{field}", value) }
    end
  end
end
