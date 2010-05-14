class Fetion
  class BuddyList
    attr_reader :id, :name
    
    def initialize(id, name)
      @id = id
      @name = name
    end
    
    def self.parse(buddy_list)
      self.new(buddy_list['id'], buddy_list['name'])
    end
  end
end