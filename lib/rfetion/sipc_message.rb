require 'guid'

class SipcMessage
  def self.register_first(fetion)
    sipc_create(:command => 'R', :F => fetion.sid, :I => 1, :Q => '1 R', :CN => ::Guid.new.hexdigest.upcase, :CL => %Q|type="pc" ,version="#{Fetion::VERSION}"|, :with_l => false)
  end

  def self.register_second(fetion)
    body = %Q|<args><device machine-code="B04B5DA2F5F1B8D01A76C0EBC841414C" /><caps value="ff" /><events value="7f" /><user-info mobile-no="#{fetion.mobile_no}" user-id="#{fetion.user_id}"><personal version="0" attributes="v4default" /><custom-config version="0" /><contact-list version="0"   buddy-attributes="v4default" /></user-info><credentials domains="fetion.com.cn;m161.com.cn;www.ikuwa.cn;games.fetion.com.cn" /><presence><basic value="400" desc="" /></presence></args>|
    sipc_create(:command => 'R', :F => fetion.sid, :I => 1, :Q => '2 R', :A => %Q|Digest response="#{fetion.response}",algorithm="SHA1-sess-v4"|, :AK => 'ak-value', :body => body)
  end

  def self.get_group_list(fetion)
    body = %Q|<args><group-list attributes="name;identity" /></args>|
    sipc_create(:command => 'S', :F => fetion.sid, :I => fetion.next_call, :Q => '1 S', :N => 'PGGetGroupList', :body => body)
  end

  def self.presence(fetion)
    body = %Q|<args><subscription self="v4default;mail-count" buddy="v4default" version="0" /></args>|
    sipc_create(:command => 'SUB', :F => fetion.sid, :I => fetion.next_call, :Q => '1 SUB', :N => 'PresenceV4', :body => body)
  end

  def self.get_group_topic(fetion)
    body = %Q|<args><topic-list /></args>|
    sipc_create(:command => 'S', :F => fetion.sid, :I => fetion.next_call, :Q => '1 S', :N => 'PGGetGroupTopic', :body => body)
  end

  def self.get_address_list(fetion)
    body = %Q|<args><contacts version="0" /></args>|
    sipc_create(:command => 'S', :F => fetion.sid, :I => fetion.next_call, :Q => '1 S', :N => 'GetAddressListV4', :body => body)
  end

  def self.send_cat_sms(fetion, receiver, content)
    sipc_create(:command => 'M', :F => fetion.sid, :I => fetion.next_call, :Q => '1 M', :T => receiver, :N => 'SendCatSMS', :body => content)
  end

  def self.send_cat_msg(fetion, receiver, content)
    sipc_create(:command => 'M', :F => fetion.sid, :I => fetion.next_call, :Q => '2 M', :T => receiver, :K => 'SaveHistory', :N => 'CatMsg', :body => content)
  end

  def self.set_schedule_sms(fetion, receivers, content, time)
    receivers_str = receivers.collect { |receiver| %Q[<receiver uri="#{receiver}" />] }.join('')
    body = %Q|<args><schedule-sms send-time="#{time}" type="0"><message>test</message><receivers>#{receivers_str}</receivers></schedule-sms></args>|
    sipc_create(:command => 'S', :F => fetion.sid, :I => fetion.next_call, :Q => '1 S', :N => 'SSSetScheduleCatSms', :SV => '1', :body => body)
  end

  def self.add_buddy(fetion, options)
    body = options[:friend_mobile] ? %Q|<args><contacts><buddies><buddy uri="tel:#{options[:friend_mobile]}" buddy-lists="" desc="#{fetion.nickname}" expose-mobile-no="1" expose-name="1" addbuddy-phrase-id="0" /></buddies></contacts></args>| : %Q|<args><contacts><buddies><buddy uri="sip:#{options[:friend_sip]}" buddy-lists="" desc="#{fetion.nickname}" addbuddy-phrase-id="0" /></buddies></contacts></args>|
    sipc_create(:command => 'S', :F => fetion.sid, :I => fetion.next_call, :Q => '1 S', :N => 'AddBuddyV4', :body => body)
  end

  def self.get_contact_info(fetion, uri)
    body = %Q|<args><contact uri="#{uri}" /></args>|
    sipc_create(:command => 'S', :F => fetion.sid, :I => fetion.next_call, :Q => '1 S', :N => 'GetContactInfoV4', :body => body)
  end

  def self.logout(fetion)
    sipc_create(:command => 'R', :F => fetion.sid, :I => 1, :Q => '3 R', :X => 0, :with_l => false)
  end

  def self.create_session(fetion, last_sipc_response)
    header = {}
    last_sipc_response.header.split("\r\n")[1..-1].each do |line|
      key, value = line.split(': ', 2)
      if key == 'K'
        header['K'] ? header['K'] << value : header['K'] = [value]
      else
        header[key] = value
      end
    end
    body = %Q|v=0\r\no=-0 0 IN 127.0.0.1:8001\r\ns=session\r\nc=IN IP4 127.0.0.1:8001\r\nt=0 0\r\nm=message 8001 sip sip:#{fetion.uri}\r\n|
    sipc_response_create(:I => header['I'], :Q => header['Q'], :F => header['F'], :K => header['K'], :body => body, :f_first => false)
  end

  def self.session_connected(fetion, last_sipc_response)
    header = {}
    last_sipc_response.header.split("\r\n")[1..-1].each do |line|
      key, value = line.split(': ', 2)
      header[key] = value
    end
    header['K'] = ['text/html-fragment', 'text/plain']
    sipc_response_create(:F => header['F'], :I => header['I'], :Q => header['Q'], :K => header['K'], :with_l => false)
  end

  def self.msg_received(fetion, last_sipc_response)
    header = {}
    last_sipc_response.header.split("\r\n")[1..-1].each do |line|
      key, value = line.split(': ', 2)
      header[key] = value
    end
    sipc_response_create(:F => header['F'], :I => header['I'], :Q => header['Q'], :with_l => false)
  end

  def self.sipc_response(http_response_body, fetion)
    return if http_response_body == Fetion::SIPP
    
    header, body = http_response_body.split(/\r\n\r\n/, 2)
    if header =~ %r{^SIP-C/4.0}
      sipc, code, message = header.split(/\r\n/).first.split(' ', 3)
      RESPONSES[code.to_i].new(code.to_i, message, header, body)
    elsif header =~ %r{(BN|M|I|O) #{fetion.sid} SIP-C/4.0}
      SipcMessage::OK.new(200, $1, header, body)
    end
  rescue NoMethodError
    raise FetionException.new("Fetion error: No response to #{code} #{message}")
  end

  class Response
    attr_reader :code, :description, :header, :body

    def initialize(code, description, header, body)
      @code = code
      @description = description
      @header = header
      @body = body
    end

    def to_s
      "#@code #@description"
    end
  end

  class OK < Response; end
  class Send < Response; end
  class Bad < Response; end
  class Unauthoried < Response; end
  class NotFound < Response; end
  class ExtentionRequired < Response; end

  RESPONSES = {
    200 => SipcMessage::OK,
    280 => SipcMessage::Send,
    400 => SipcMessage::Bad,
    401 => SipcMessage::Unauthoried,
    404 => SipcMessage::NotFound,
    421 => SipcMessage::ExtentionRequired
  }

  private
    # command       one of 'R', 'S'
    # with_l        display L or not
    # body          sipc body
    def self.sipc_create(options)
      options = {:body => '', :with_l => true}.merge(options)
      body = options.delete(:body)
      with_l = options.delete(:with_l)

      sorted_key = [:F, :I, :Q, :CN, :CL, :A, :AK, :X, :T, :K, :N, :SV]
      sipc = "#{options.delete(:command)} fetion.com.cn SIP-C/4.0\r\n"
      sorted_key.each {|k| sipc += "#{k}: #{options[k]}\r\n" if options[k]}
      sipc += "L: #{body == '' ? 4 : body.size}\r\n" if with_l
      sipc += "\r\n#{body}#{Fetion::SIPP}"
      sipc
    end

    def self.sipc_response_create(options)
      options = {:body => '', :with_l => true, :f_first => true}.merge(options)
      body = options.delete(:body)
      with_l = options.delete(:with_l)

      sorted_key = options.delete(:f_first) ? [:F, :I, :Q, :K] : [:I, :Q, :F, :K]
      sipc = "SIP-C/4.0 200 OK\r\n"
      sorted_key.each do |k|
        if options[k]
          if k == :K
            sipc += options[:K].collect { |v| "#{k}: #{v}\r\n" }.join("")
          else
            sipc += "#{k}: #{options[k]}\r\n"
          end
        end
      end
      sipc += "L: #{body == '' ? 4 : body.size}\r\n" if with_l
      sipc += "\r\n#{body}#{Fetion::SIPP}"
      sipc
    end
end
