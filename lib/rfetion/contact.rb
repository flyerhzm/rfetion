#coding: utf-8
class Fetion
  class Contact
    attr_accessor :uid, :sid, :bid, :uri, :mobile_no, :nickname, :impresa, :nickname, :status

    STATUS = {
      "400" => "在线",
      "300" => "离开",
      "600" => "繁忙",
      "0" => "脱机"
    }

    def initialize(options={})
      options.each do |key, value|
        send("#{key}=", value)
      end
    end

    def update(p)
      self.sid = p["sid"]
      self.uri = p["su"]
      self.mobile_no = p["m"]
      self.nickname = p["n"]
      self.impresa = p["i"]
      self.status = p["b"]
    end

    def self.parse_buddy(b)
      self.new(:uid => b['i'], :uri => b['u'], :nickname => b['n'])
    end

    def self.parse(c)
      p = c.children.first
      self.new(:uid => c['id'], :sid => p['sid'], :uri => p['su'], :mobile_no => p['m'], :nickname => p['n'], :impresa => p['i'], :status => p['b'], :bid => p['l'])
    end

    def self.parse_request(c)
      self.new(:uri => c['uri'], :uid => c['user-id'], :sid => c['sid'], :mobile_no => c['mobile-no'], :nickname => c['nickname'])
    end
  end
end
