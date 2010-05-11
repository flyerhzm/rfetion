class Fetion
  class Contact
    attr_accessor :id, :sid, :uri, :mobile_no, :nickname, :impresa, :nickname, :status

    STATUS = {
      "400" => "在线",
      "300" => "离开",
      "600" => "繁忙",
      "0" => "脱机"
    }

    def self.parse(c)
      contact = self.new
      contact.id = c['id']
      p = c.children.first
      contact.sid = p["sid"]
      contact.uri = p["su"]
      contact.mobile_no = p["m"]
      contact.nickname = p["n"]
      contact.impresa = p["i"]
      contact.status = p["b"]
      contact
    end
  end
end
