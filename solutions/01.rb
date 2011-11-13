class Array
  def to_hash
    inject ({}) do |so_far, to_add| 
      so_far[to_add.first] = to_add.last
      so_far
    end
  end

  def index_by
    raise ArgumentError unless block_given?
    to_return = {}
    self.each { |el| to_return[yield el] = el }
    to_return
  end

  def subarray_count(subarray)
    raise ArgumentException if subarray.empty?
    each_cons(subarray.length).count(subarray)
  end

  def occurences_count
    Hash.new(0).tap do |to_return|
      self.each do |el|
        to_return[el] += 1
      end
    end
  end
end
