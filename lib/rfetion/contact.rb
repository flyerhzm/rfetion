#coding: utf-8
class Fetion
  class Contact
    attr_accessor :uid, :sid, :bid, :uri, :mobile_no, :nickname, :impresa, :status

    STATUS = {
      "400" => "在线",
      "300" => "离开",
      "600" => "繁忙",
      "0" => "脱机"
    }
    
    def to_json(*args)
      {:uid => @uid, :sid => @sid, :bid => @bid, :uri => @uri, :mobile_no => @mobile_no, :nickname => @nickname, :impresa => @impresa, :status => @status}.to_json(*args)
    end

    def self.parse_buddy(b)
      self.new(:uid => b['i'], :uri => b['u'], :nickname => b['n'], :bid => b['l'].empty? ? "0" : b['l'])
    end

    def self.parse(c)
      p = c.children.first
      self.new(:uid => c['id'], :sid => p['sid'], :uri => p['su'], :mobile_no => p['m'], :nickname => p['n'], :impresa => p['i'], :status => p['b'], :bid => p['l'])
    end

    def self.parse_request(c)
      self.new(:uri => c['uri'], :uid => c['user-id'], :sid => c['sid'], :mobile_no => c['mobile-no'], :nickname => c['nickname'])
    end

    def initialize(options={})
      options.each do |key, value|
        send("#{key}=", value)
      end
    end

    def update(p)
      self.sid = p["sid"] if p["sid"] and !p["sid"].empty?
      self.uri = p["su"] if p["su"] and !p["su"].empty?
      self.mobile_no = p["m"] if p["m"] and !p["m"].empty?
      self.nickname = p["n"] if p["n"] and !p["n"].empty?
      self.impresa = p["i"] if p["i"] and !p["i"].empty?
      self.status = p["b"] if p["b"] and !p["b"].empty?
    end

    def display
      if self.impresa and !self.impresa.empty?
        "#{self.nickname}(#{self.impresa})"
      elsif self.nickname and !self.nickname.empty?
        self.nickname
      else
        if self.uri =~ /^(tel|sip):(\d+)/
          $2
        end
      end
    end
  end
end
