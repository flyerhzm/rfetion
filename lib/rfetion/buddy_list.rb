class Fetion
  class BuddyList
   attr_reader :bid, :name, :contacts
    
    def initialize(bid, name)
      @bid = bid
      @name = name
      @contacts = []
    end
    
    def to_json(*args)
      {:bid => @bid, :name => @name, :contacts => @contacts, :total_contacts => total_contacts_count, :online_contacts => online_contacts_count}.to_json(*args)
    end
    
    def self.parse(buddy_list)
      self.new(buddy_list['id'], buddy_list['name'])
    end

    def add_contact(contact)
      @contacts << contact
    end

    def online_contacts_count
      @contacts.select {|contact| contact.status == "400"}.size
    end

    def total_contacts_count
      @contacts.size
    end
  end
end
