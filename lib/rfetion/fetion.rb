require 'guid'
require 'time'
require 'net/http'
require 'net/https'
require 'nokogiri'
require 'digest/sha1'
require 'openssl'
require 'logger'

class Fetion
  attr_accessor :mobile_no, :sid, :password
  attr_reader :user_id, :uri, :contacts, :buddy_lists, :response, :nickname, :receives

  FETION_URL = 'http://221.176.31.39/ht/sd.aspx'
  FETION_LOGIN_URL = 'https://uid.fetion.com.cn/ssiportal/SSIAppSignInV4.aspx?mobileno=%mobileno%sid=%sid%&domains=fetion.com.cn;m161.com.cn;www.ikuwa.cn&v4digest-type=1&v4digest=%digest%'

  SIPP = 'SIPP'
  USER_AGENT = "IIC2.0/PC 3.6.2020"
  VERSION = "3.6.2020"
  DOMAIN = "fetion.com.cn"

  def initialize
    @call = @alive = @seq = 0
    @buddy_lists = []
    @buddies = []
    @contacts = []
    @receives = []
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    @guid = Guid.new.to_s
  end
  
  def logger_level=(level)
    @logger.level = level
  end

  def Fetion.open(options, &block)
    fetion = Fetion.new
    fetion.logger_level = options.delete(:logger_level) || Logger::INFO
    fetion.mobile_no = options.delete(:mobile_no)
    fetion.sid = options.delete(:sid)
    fetion.password = options.delete(:password)
    fetion.login
    fetion.register

    fetion.instance_eval &block

    fetion.logout
  end

  # options
  #   mobile_no
  #   sid
  #   password
  #   receivers
  #   content
  #   logger_level
  def Fetion.send_sms(options)
    Fetion.open(options) do
      receivers = options.delete(:receivers)
      content = options.delete(:content)
      if receivers
        receivers = Array(receivers)
        receivers.collect! {|receiver| receiver.to_s}
        get_contacts
        contacts.each do |contact|
          if receivers.include? contact.mobile_no.to_s or receivers.any? { |receiver| contact.uri.index(receiver) }
            send_sms(contact.uri, content)
          end
        end
        send_sms(uri, content) if  receivers.any? { |receiver| self? receiver }
      else
        send_sms(uri, content)
      end
    end
  end
  
  # options
  #   mobile_no
  #   sid
  #   password
  #   receivers
  #   content
  #   logger_level
  def Fetion.send_msg(options)
    Fetion.open(options) do
      receivers = options.delete(:receivers)
      content = options.delete(:content)
      if receivers
        receivers = Array(receivers)
        receivers.collect! {|receiver| receiver.to_s}
        get_contacts
        contacts.each do |contact|
          if receivers.include? contact.mobile_no.to_s or receivers.any? { |receiver| contact.uri.index(receiver) }
            send_msg(contact.uri, content)
          end
        end
        send_msg(uri, content) if  receivers.any? { |receiver| self? receiver }
      else
        send_msg(uri, content)
      end
    end
  end

  # options
  #   mobile_no
  #   sid
  #   password
  #   receivers
  #   content
  #   time
  #   logger_level
  def Fetion.set_schedule_sms(options)
    Fetion.open(options) do
      receivers = options.delete(:receivers)
      content = options.delete(:content)
      time = options.delete(:time)
      get_contacts
      if receivers
        receivers = Array(receivers)
        receivers.collect! {|receiver| receiver.to_s}
        new_receivers = contacts.collect do |contact|
          if receivers.include? contact.mobile_no.to_s or receivers.any? { |receiver| contact.uri.index(receiver) }
            contact.uri
          end
        end.compact!
        new_receivers << uri if receivers.any? { |receiver| self? receiver }
        set_schedule_sms(new_receivers, content, time)
      else  
        set_schedule_sms([fetion.uri], content, time)
      end
    end
  end

  # options
  #   mobile_no
  #   sid
  #   password
  #   friend_mobile
  #   friend_sip
  #   logger_level
  def Fetion.add_buddy(options)
    Fetion.open(options) do
      add_buddy(options)
    end
  end

  def login
    @logger.info "fetion login"

    if @mobile_no
      url = FETION_LOGIN_URL.sub('%mobileno%', @mobile_no).sub('sid=%sid%', '')
    else
      url = FETION_LOGIN_URL.sub('%sid%', @sid).sub('mobileno=%mobileno%', '')
    end
    uri = URI.parse(url.sub('%digest%', Digest::SHA1.hexdigest("#{DOMAIN}:#{@password}")))
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    headers = {'User-Agent' => USER_AGENT}
    response = http.request_get(uri.request_uri, headers)
    parse_ssic(response)

    @logger.info "fetion login success"
  end

  def register
    @logger.info "fetion register"

    call = next_call
    register_first
    register_second
    call = next_call

    @logger.info "fetion register success"
  end

  def register_first
    @logger.debug "fetion register first"

    curl_exec(SIPP, next_url('i'))
    curl_exec(SipcMessage.register_first(self))
    pulse(SipcMessage::Unauthoried)

    @logger.debug "fetion register first success"
  end

  def register_second
    @logger.debug "fetion register second"

    body = %Q|<args><device machine-code="B04B5DA2F5F1B8D01A76C0EBC841414C" /><caps value="ff" /><events value="7f" /><user-info mobile-no="#{@mobile_no}" user-id="#{@user_id}"><personal version="0" attributes="v4default" /><custom-config version="0" /><contact-list version="0"   buddy-attributes="v4default" /></user-info><credentials domains="fetion.com.cn;m161.com.cn;www.ikuwa.cn;games.fetion.com.cn" /><presence><basic value="400" desc="" /></presence></args>|
    curl_exec(SipcMessage.register_second(self))
    pulse

    @logger.debug "fetion register second success"
  end

  def get_contacts
    @logger.info "fetion get contacts"

    curl_exec(SipcMessage.get_group_list(self))
    curl_exec(SipcMessage.presence(self))
    curl_exec(SipcMessage.get_group_topic(self))
    curl_exec(SipcMessage.get_address_list(self))
    pulse

    @logger.info "fetion get contacts success"
  end

  def send_msg(receiver, content)
    @logger.info "fetion send cat msg to #{receiver}"

    curl_exec(SipcMessage.send_cat_msg(self, receiver, content))
    pulse

    @logger.info "fetion send cat msg to #{receiver} success"
  end

  def send_sms(receiver, content)
    @logger.info "fetion send cat sms to #{receiver}"

    curl_exec(SipcMessage.send_cat_sms(self, receiver, content))
    pulse(SipcMessage::Send)

    @logger.info "fetion send cat sms to #{receiver} success"
  end

  def set_schedule_sms(receivers, content, time)
    receivers = Array(receivers)
    time = time.is_a?(Time) ? time : Time.parse(time)
    now = Time.now
    one_year = Time.local(now.year + 1, now.month, now.day, now.hour, now.min, now.sec)
    raise SetScheduleSmsException.new("Can't schedule send sms to more than 64 receivers") if receivers.size > 64
    raise SetScheduleSmsException.new("Schedule time must between #{(now + 600).strftime('%Y-%m-%d %H:%M:%S')} and #{one_year.strftime('%Y-%m-%d %H:%M:%S')}") if time < (now + 600) or time > one_year
    @logger.info "fetion schedule send sms to #{receivers.join(', ')}"
    
    curl_exec(SipcMessage.set_schedule_sms(self, receivers, content, time.strftime('%Y-%m-%d %H:%M:%S')))
    pulse

    @logger.info "fetion schedule send sms to #{receivers.join(', ')} success"
  end

  # options
  #   friend_mobile
  #   friend_sip
  def add_buddy(options)
    uri = options[:friend_mobile] ? "tel:#{options[:friend_mobile]}" : "sip:#{options[:friend_sip]}"
    @logger.info "fetion send request to add #{uri} as friend"
    
    curl_exec(SipcMessage.add_buddy(self, options))
    pulse

    @logger.info "fetion send request to add #{uri} as friend success"
  end

  # options
  #   mobile_no
  #   sip
  def get_contact_info(options)
    uri = options[:mobile_no] ? "tel:#{options[:mobile_no]}" : "sip:#{options[:sip]}"
    @logger.info "fetion get contact info of #{uri}"
    
    curl_exec(SipcMessage.get_contact_info(self, uri))
    pulse

    @logger.info "fetion get contact info of #{uri} success"
  end

  def keep_alive
    @logger.info "fetion keep alive"
    
    pulse

    @logger.info "fetion keep alive success"
  end

  def logout
    @logger.info "fetion logout"

    curl_exec(SipcMessage.logout(self))
    pulse

    @logger.info "fetion logout success"
  end

  def parse_ssic(response)
    raise Fetion::LoginException.new('Fetion Error: Login failed.') unless Net::HTTPSuccess === response
    raise Fetion::LoginException.new('Fetion Error: No ssic found in cookie.') unless response['set-cookie'] =~ /ssic=(.*);/

    @ssic = $1
    @logger.debug response.body
    doc = Nokogiri::XML(response.body)
    results = doc.root
    @status_code = results["status-code"]
    user = results.children.first
    @user_status = user['user-status']
    @uri = user['uri']
    @mobile_no = user['mobile-no']
    @user_id = user['user-id']
    if @uri =~ /sip:(\d+)@(.+);/
      @sid = $1
    end

    @logger.debug "ssic: " + @ssic
    @logger.debug "status_code: " + @status_code
    @logger.debug "user_status: " + @user_status
    @logger.debug "uri: " + @uri
    @logger.debug "mobile_no: " + @mobile_no
    @logger.debug "user_id: " + @user_id
    @logger.debug "sid: " + @sid
  end

  def pulse(expected=SipcMessage::OK)
    curl_exec(SIPP, next_url, expected)
  end

  def curl_exec(body='', url=next_url, expected=SipcMessage::OK)
    @logger.debug "fetion curl exec"
    @logger.debug "url: #{url}"
    @logger.debug "body: #{body}"
    
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    headers = {'Content-Type' => 'application/oct-stream', 'Pragma' => "xz4BBcV#{@guid}", 'User-Agent' => USER_AGENT, 'Cookie' => "ssic=#{@ssic}", 'Content-Length' => body.length.to_s}
    response = http.request_post(uri.request_uri, body, headers)

    @logger.debug "response: #{response.inspect}"
    @logger.debug "response body: #{response.body}"
    @logger.debug "fetion curl exec complete"
    
    raise FetionException.new("request_url: #{url}, request_body: #{body}, response: #{response.code}, response_body: #{response.body}") unless Net::HTTPSuccess === response
    sipc_response = SipcMessage.sipc_response(response.body, self)
    
    if sipc_response
      raise Fetion::SipcException.new(sipc_response, "request_url: #{url}, request_body: #{body}, sipc_response: #{sipc_response}") unless expected === sipc_response
    
      if sipc_response.code == 401
        # unauthorized, get nonce, key and signature
        raise Fetion::NoNonceException.new("Fetion Error: No nonce found") unless response.body =~ /nonce="(.*?)",key="(.*?)",signature="(.*?)"/
        @nonce = $1
        @key = $2
        @signature = $3
        @response = calc_response

        @logger.debug "nonce: #{@nonce}"
        @logger.debug "key: #{@key}"
        @logger.debug "signature: #{@signature}"
        @logger.debug "response: #{@response}"
      else
        response.body.scan(%r{<results>.*?</results>}).each do |results|
          doc = Nokogiri::XML(results)
          doc.root.xpath("/results/user-info/personal").each do |personal_element|
            @nickname = personal_element['nickname']
            @logger.debug "nickname: #@nickname"
          end
          doc.root.xpath("/results/user-info/contact-list/buddy-lists/buddy-list").each do |buddy_list|
            @buddy_lists << Fetion::BuddyList.parse(buddy_list)
            @logger.debug "buddy_lists: #{@buddy_lists.inspect}"
          end
          doc.root.xpath("/results/user-info/contact-list/buddies/b").each do |buddy|
            @buddies << {:uri => buddy["u"]}
            @logger.debug "buddies: #{@buddies.inspect}"
          end
        end
        
        response.body.scan(%r{<events>.*?</events>}).each do |events|
          doc = Nokogiri::XML(events)
          doc.root.xpath("/events/event[@type='PresenceChanged']/contacts/c").each do |c|
            contact = contacts.find {|contact| contact.id == c['id']}
            if contact
              contact.status = c.children.first['b']
            else
              @contacts << Fetion::Contact.parse(c) unless c['id'] == @user_id
            end
          end
        end
        
        receive_messages = response.body.scan(%r{M #{@sid} SIP-C/4.0.*?BN}m)
        receive_messages = response.body.scan(%r{M #{@sid} SIP-C/4.0.*?SIPP$}m) if receive_messages.empty?
        receive_messages.each do |message_response|
          message_header, message_content = message_response.split(/(\r)?\n(\r)?\n/)
          sip = sent_at = length = nil
          message_header.split(/(\r)?\n/).each do |line|
            case line
            when /^F: sip:(.+)/ then sip = $1
            when /^D: (.+)/ then sent_at = Time.parse($1)
            when /^L: (\d+)/ then length = $1.to_i
            end
          end
          text = message_content.slice(0, length)
          @receives << Fetion::Message.new(sip, sent_at, text)
        end
      end
    end
    response
  end

  def next_url(t = 's')
    FETION_URL + "?t=#{t}&i=#{next_seq}"
  end

  def next_call
    @call += 1
  end

  def next_seq
    @seq += 1
  end

  def next_alive
    @alive += 1
  end

  def calc_response
    encrypted_password = Digest::SHA1.hexdigest([@user_id.to_i].pack("V*") + [Digest::SHA1.hexdigest("#{DOMAIN}:#{@password}")].pack("H*"))
    rsa_result = "4A026855890197CFDF768597D07200B346F3D676411C6F87368B5C2276DCEDD2"
    str = @nonce + [encrypted_password].pack("H*") + [rsa_result].pack("H*")
    rsa_key = OpenSSL::PKey::RSA.new
    exponent = OpenSSL::BN.new @key[-6..-1].hex.to_s
    modulus = OpenSSL::BN.new @key[0...-6].hex.to_s
    rsa_key.e = exponent
    rsa_key.n = modulus

    rsa_key.public_encrypt(str).unpack("H*").first.upcase
  end
  
  def self?(mobile_or_sid)
    mobile_or_sid == @mobile_no or mobile_or_sid == @sid
  end
end

class FetionException < Exception; end
class Fetion::LoginException < FetionException; end
class Fetion::NoNonceException < FetionException; end
class Fetion::RegisterException < FetionException; end
class Fetion::SendSmsException < FetionException; end
class Fetion::SendMsgException < FetionException; end
class Fetion::SetScheduleSmsException < FetionException; end
class Fetion::AddBuddyException < FetionException; end
class Fetion::GetContactsException < FetionException; end
class Fetion::NoUserException < FetionException; end
class Fetion::SipcException < FetionException
  attr_reader :code, :description, :message
  
  def initialize(sipc_response, message)
    @code = sipc_response.code
    @description = sipc_response.description
    @message = message
  end
end