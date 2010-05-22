class Fetion
  class BuddyList
   attr_reader :bid, :name, :contacts
    
    def initialize(bid, name)
      @bid = bid
      @name = name
      @contacts = []
    end
    
    def self.parse(buddy_list)
      self.new(buddy_list['id'], buddy_list['name'])
    end

    def add_contact(contact)
      @contacts << contact
    end
  end
end
