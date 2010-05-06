require 'rubygems'
require 'guid'
require 'time'
require 'net/http'
require 'net/https'
require 'nokogiri'
require 'digest/sha1'
require 'openssl'
require 'logger'

class FetionException < Exception
end

class Fetion
  attr_accessor :mobile_no, :sid, :password
  attr_reader :uri, :contacts

  FETION_URL = 'http://221.130.44.194/ht/sd.aspx'
  FETION_LOGIN_URL = 'https://uid.fetion.com.cn/ssiportal/SSIAppSignInV4.aspx?mobileno=%mobileno%sid=%sid%&domains=fetion.com.cn;m161.com.cn;www.ikuwa.cn&v4digest-type=1&v4digest=%digest%'

  SIPP = 'SIPP'
  USER_AGENT = "IIC2.0/PC 3.6.2020"
  VERSION = "3.6.2020"
  SIPC_HEADER = "R fetion.com.cn SIP-C/4.0"
  DOMAIN = "fetion.com.cn"

  def initialize
    @call = 0
    @alive = 0
    @seq = 0
    @alive_call = 0
    @buddies = []
    @contacts = []
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    @cat = true
    @guid = ::Guid.new.to_s
  end
  
  def logger_level=(level)
    @logger.level = level
  end

  # options
  #   mobile_no
  #   sid
  #   password
  #   receivers
  #   content
  #   logger_level
  def Fetion.send_sms(options)
    fetion = Fetion.new
    fetion.logger_level = options[:logger_level] || Logger::INFO
    fetion.mobile_no = options[:mobile_no]
    fetion.sid = options[:sid]
    fetion.password = options[:password]
    fetion.login
    fetion.register
    receivers = options[:receivers]
    content = options[:content]
    if receivers
      receivers = Array(receivers)
      receivers.collect! {|receiver| receiver.to_s}
      fetion.get_buddy_list
      fetion.get_contacts_info
      fetion.contacts.each do |contact|
        if receivers.include? contact.mobile_no.to_s or receivers.any? { |receiver| contact.uri.index(receiver) }
          fetion.send_sms(contact.uri, content)
        end
      end
      fetion.send_sms(fetion.uri, content) if  receivers.any? { |receiver| fetion.self? receiver }
    else
      fetion.send_sms(fetion.uri, content)
    end
    fetion.logout
  end
  
  # options
  #   mobile_no
  #   sid
  #   password
  #   receivers
  #   content
  #   logger_level
  def Fetion.send_msg(options)
    fetion = Fetion.new
    fetion.logger_level = options[:logger_level] || Logger::INFO
    fetion.mobile_no = options[:mobile_no]
    fetion.sid = options[:sid]
    fetion.password = options[:password]
    fetion.login
    fetion.register
    receivers = options[:receivers]
    content = options[:content]
    if receivers
      receivers = Array(receivers)
      receivers.collect! {|receiver| receiver.to_s}
      fetion.get_buddy_list
      fetion.get_contacts_info
      fetion.contacts.each do |contact|
        if receivers.include? contact.mobile_no.to_s or receivers.any? { |receiver| contact.uri.index(receiver) }
          fetion.send_msg(contact.uri, content)
        end
      end
      fetion.send_msg(fetion.uri, content) if  receivers.any? { |receiver| fetion.self? receiver }
    else
      fetion.send_msg(fetion.uri, content)
    end
    fetion.logout
  end

  # options
  #   mobile_no
  #   sid
  #   password
  #   receivers
  #   content
  #   time
  #   logger_level
  def Fetion.schedule_sms(options)
    fetion = Fetion.new
    fetion.logger_level = options[:logger_level] || Logger::INFO
    fetion.mobile_no = options[:mobile_no]
    fetion.sid = options[:sid]
    fetion.password = options[:password]
    fetion.login
    fetion.register
    receivers = options[:receivers]
    content = options[:content]
    time = options[:time]
    fetion.get_buddy_list
    fetion.get_contacts_info
    if receivers
      receivers = Array(receivers)
      receivers.collect! {|receiver| receiver.to_s}
      new_receivers = fetion.contacts.collect do |contact|
        if receivers.include? contact.mobile_no.to_s or receivers.any? { |receiver| contact.uri.index(receiver) }
          contact.uri
        end
      end.compact!
      new_receivers << fetion.uri if receivers.any? { |receiver| fetion.self? receiver }
      fetion.schedule_sms(new_receivers, content, time)
    else  
      fetion.schedule_sms([fetion.uri], content, time)
    end
    fetion.logout
  end

  # options
  #   mobile_no
  #   sid
  #   password
  #   friend_mobile
  #   friend_sip
  #   logger_level
  def Fetion.add_buddy(options)
    fetion = Fetion.new
    fetion.logger_level = options[:logger_level] || Logger::INFO
    fetion.mobile_no = options[:mobile_no]
    fetion.sid = options[:sid]
    fetion.password = options[:password]
    fetion.login
    fetion.register
    fetion.get_personal_info
    fetion.add_buddy(options)
    fetion.logout
  end

  def login
    @logger.info "fetion login"
    if @mobile_no
      url = FETION_LOGIN_URL.sub('%mobileno%', @mobile_no).sub('sid=%sid%', '')
    else
      url = FETION_LOGIN_URL.sub('%sid%', @sid).sub('%mobileno%', '')
    end
    uri = URI.parse(url.sub('%digest%', Digest::SHA1.hexdigest("#{DOMAIN}:#{@password}")))
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    headers = {'User-Agent' => USER_AGENT}
    response = http.request_get(uri.request_uri, headers)

    raise FetionException.new('Fetion Error: Login failed.') unless response.is_a? Net::HTTPSuccess
    raise FetionException.new('Fetion Error: No ssic found in cookie.') unless response['set-cookie'] =~ /ssic=(.*);/

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
    @logger.info "fetion login success"
  end

  def register
    @logger.info "fetion http register"
    call = next_call

    register_first(call)
    register_second(call)

    @logger.info "fetion http register success"
  end

  def register_first(call)
    @logger.debug "fetion http register first"

    curl_exec(SIPP, next_url('i'))
    curl_exec(sip_create('F' => @sid, 'I' => call, 'CN' => ::Guid.new.hexdigest.upcase, 'CL' => %Q|type="pc" ,version="#{VERSION}"|))
    response = pulse
    raise FetionException.new("Fetion Error: no nonce found") unless response.body =~ /nonce="(.*?)",key="(.*?)",signature="(.*?)"/
      
    @nonce = $1
    @key = $2
    @signature = $3

    @reponse = calc_response

    @logger.debug "nonce: #{@nonce}"
    @logger.debug "key: #{@key}"
    @logger.debug "signature: #{@signature}"
    @logger.debug "response: #{@response}"
    @logger.debug "fetion http register first success"
  end

  def register_second(call)
    @logger.debug "fetion http register second"

    body = %Q|<args><device machine-code="B04B5DA2F5F1B8D01A76C0EBC841414C" /><caps value="1ff" /><events value="7f" /><user-info mobile-no="#{@mobile_no}" user-id="#{@user_id}"><personal version="0" attributes="v4default" /><custom-config version="0" /><contact-list version="0"   buddy-attributes="v4default" /></user-info><credentials domains="fetion.com.cn;m161.com.cn;www.ikuwa.cn;games.fetion.com.cn" /><presence><basic value="400" desc="" /></presence></args>|
    curl_exec(sip_create({'F' => @sid, 'I' => call, 'A' => %Q|Digest response="#{@response}"|, 'AK' => 'ak-value'}, body))
    response = pulse

    raise FetionException.new('Fetion Error: Register failed.') unless response.is_a? Net::HTTPSuccess
    @logger.debug "fetion http register second success"
  end


  def keep_alive
    @logger.debug "fetion keep alive"

    msg = sip_create('R fetion.com.cn SIP-C/2.0', {'F' => @sid, 'I' => call, 'Q' => "#{next_alive} R"}) + FETION_SIPP
    curl_exec(next_url, @ssic, msg)
    response = curl_exec(next_url, @ssic, FETION_SIPP)

    raise FetionException.new('Fetion Error: Register failed.') unless response.is_a? Net::HTTPSuccess
    @logger.debug "fetion keep alive success"
  end

  def get_buddy_list
    @logger.info "fetion get buddy list"
    arg = '<args><contacts><buddy-lists /><buddies attributes="all" /><mobile-buddies attributes="all" /><chat-friends /><blacklist /><allow-list /></contacts></args>'
    msg = sip_create('S fetion.com.cn SIP-C/2.0', {'F' => @sid, 'I' => next_call, 'Q' => '1 S', 'N' => 'GetContactList'}, arg) + FETION_SIPP
    curl_exec(next_url, @ssic, msg)
    response = curl_exec(next_url, @ssic, FETION_SIPP)
    raise FetionException.new("Fetion Error: Get buddy list error") unless response.is_a? Net::HTTPSuccess

    response.body.scan(%r{<results>.*?</results>}).each do |results|
      doc = Nokogiri::XML(results)
      doc.root.xpath("/results/contacts/allow-list/contact").each do |contact|
        @buddies << {:uri => contact["uri"]}
      end
    end
    @logger.debug "buddies: #{@buddies.inspect}"
    @logger.info "fetion get buddy list success"
  end

  def get_contacts_info
    @logger.info "fetion get contacts info"
    arg = '<args><contacts attributes="provisioning;impresa;mobile-no;nickname;name;gender;portrait-crc;ivr-enabled" extended-attributes="score-level">'
    @buddies.each do |buddy|
      arg += "<contact uri=\"#{buddy[:uri]}\" />"
    end
    arg += '</contacts></args>'

    msg = sip_create('S fetion.com.cn SIP-C/2.0', {'F' => @sid, 'I' => next_call, 'Q' => '1 S', 'N' => 'GetContactsInfo'}, arg) + FETION_SIPP
    curl_exec(next_url, @ssic, msg)
    while true do
      sleep 1
      response = curl_exec(next_url, @ssic, FETION_SIPP)
      raise FetionException.new("Fetion Error: Get contacts info error") unless response.is_a? Net::HTTPSuccess
      break if response.body.size > FETION_SIPP.size
    end

    response.body.scan(%r{<results>.*?</results>}).each do |results|
      doc = Nokogiri::XML(results)
      doc.root.xpath("/results/contacts/contact").each do |contact|
        attrs = contact.children.size == 0 ? {} : contact.children.first
        @contacts << Contact.new(contact["uri"], attrs)
      end
    end
    @logger.debug @contacts.inspect
    @logger.info "fetion get contacts info success"
  end

  def send_msg(receiver, content)
    @logger.info "fetion SendMsg to #{receiver}"
    msg = sip_create('M fetion.com.cn SIP-C/2.0', {'F' => @sid, 'I' => next_call, 'Q' => '3 M', 'T' => receiver, 'C' => 'text/html-fragment', 'K' => 'SaveHistory'}, content) + FETION_SIPP
    curl_exec(next_url, @ssic, msg)
    response = curl_exec(next_url, @ssic, FETION_SIPP)

    raise FetionException.new("Fetion Error: Send sms error") unless response.is_a? Net::HTTPSuccess
    @logger.info "fetion SendMsg to #{receiver} success"
  end

  def send_sms(receiver, content)
    @logger.info "fetion #{send_command} to #{receiver}"
    msg = sip_create('M fetion.com.cn SIP-C/2.0', {'F' => @sid, 'I' => next_call, 'Q' => '1 M', 'T' => receiver, 'N' => send_command}, content) + FETION_SIPP
    curl_exec(next_url, @ssic, msg)
    response = curl_exec(next_url, @ssic, FETION_SIPP)

    raise FetionException.new("Fetion Error: Send sms error") unless response.is_a? Net::HTTPSuccess
    @logger.info "fetion #{send_command} to #{receiver} success"
  end

  def schedule_sms(receivers, content, time)
    receivers = Array(receivers)
    time = time.is_a?(Time) ? time : Time.parse(time)
    now = Time.now
    one_year = Time.local(now.year + 1, now.month, now.day, now.hour, now.min, now.sec)
    raise FetionException.new("Can't schedule send sms to more than 32 receivers") if receivers.size > 32
    raise FetionException.new("Schedule time must between #{(now + 600).strftime('%Y-%m-%d %H:%M:%S')} and #{one_year.strftime('%Y-%m-%d %H:%M:%S')}") if time < (now + 600) or time > one_year
    @logger.info "fetion schedule send sms to #{receivers.join(', ')}"
    
    receivers_str = receivers.collect { |receiver| %Q[<receiver uri="#{receiver}" />] }.join('')
    arg = %Q{<args><schedule-sms send-time="#{time.getutc.strftime('%Y-%m-%d %H:%M:%S')}"><message>#{content}</message><receivers>#{receivers_str}</receivers></schedule-sms></args>}
    msg = sip_create('S fetion.com.cn SIP-C/2.0', {'F' => @sid, 'I' => next_call, 'Q' => '1 S', 'N' => 'SSSetScheduleCatSms'}, arg) + FETION_SIPP
    curl_exec(next_url, @ssic, msg)
    response = curl_exec(next_url, @ssic, FETION_SIPP)

    raise FetionException.new("Fetion Error: Schedule sms error") unless response.is_a? Net::HTTPSuccess
    @logger.info "fetion schedule send sms to #{receivers.join(', ')} success"
  end

  def get_personal_info
    @logger.info "fetion get personal info"
    arg = %Q{<args><personal attributes="all" /><services version="" attributes="all" /><config version="96" attributes="all" /><mobile-device attributes="all" /></args>}
    msg = sip_create('S fetion.com.cn SIP-C/2.0', {'F' => @sid, 'I' => next_call, 'Q' => '1 S', 'N' => 'GetPersonalInfo'}, arg) + FETION_SIPP
    curl_exec(next_url, @ssic, msg)
    response = curl_exec(next_url, @ssic, FETION_SIPP)
    raise FetionException.new("Fetion Error: Get personal info error") unless response.is_a? Net::HTTPSuccess

    doc = Nokogiri::XML(response.body.chomp(FETION_SIPP))
    @person = doc.root.xpath('/results/personal').first
    @logger.info "fetion get personal info success"
  end

  # options
  #   friend_mobile
  #   friend_sip
  def add_buddy(options)
    uri = options[:friend_mobile] ? "tel:#{options[:friend_mobile]}" : "sip:#{options[:friend_sip]}"

    @logger.info "fetion send request to add #{uri} as friend"
    arg = %Q{<args><contacts><buddies><buddy uri="#{uri}" local-name="" buddy-lists="1" desc="#{@person['nickname']}" expose-mobile-no="1" expose-name="1" /></buddies></contacts></args>}
    msg = sip_create('S fetion.com.cn SIP-C/2.0', {'F' => @sid, 'I' => next_call, 'Q' => '1 S', 'N' => 'AddBuddy'}, arg) + FETION_SIPP
    curl_exec(next_url, @ssic, msg)
    response = curl_exec(next_url, @ssic, FETION_SIPP)
    raise FetionException.new("Fetion Error: Add buddy error") unless response.is_a? Net::HTTPSuccess

    if response.body =~ /No Subscription/
      raise FetionException.new("Fetion Error: No #{uri}") if options[:friend_sip]

      arg = %Q{<args><contacts><mobile-buddies><mobile-buddy uri="#{uri}" local-name="" buddy-lists="1" desc="#{@person['nickname']}" expose-mobile-no="1" expose-name="1" /></mobile-buddies></contacts></args>}
      msg = sip_create('S fetion.com.cn SIP-C/2.0', {'F' => @sid, 'I' => next_call, 'Q' => '1 S', 'N' => 'AddMobileBuddy'}, arg) + FETION_SIPP
      curl_exec(next_url, @ssic, msg)
      response = curl_exec(next_url, @ssic, FETION_SIPP)
      raise FetionException.new("Fetion Error: Add buddy error") unless response.is_a? Net::HTTPSuccess

      raise FetionException.new("Fetion Error: No #{uri}") if response.body =~ /Not Found/
    end
    @logger.info "fetion send request to add #{uri} as friend success"
  end

  def logout
    @logger.info "fetion logout"
    msg = sip_create('R fetion.com.cn SIP-C/2.0', {'F' => @sid, 'I' => 1, 'Q' => '3 R', 'X' => 0}, '') + FETION_SIPP
    curl_exec(next_url, @ssic, msg)
    response = curl_exec(next_url, @ssic, FETION_SIPP)

    # raise FetionException.new("Fetion Error: Logout error") unless response.is_a? Net::HTTPSuccess
    @logger.info "fetion logout success"
  end

  def pulse
    curl_exec(SIPP)
  end

  def curl_exec(body='', url=next_url)
    @logger.debug "fetion curl exec"
    @logger.debug "url: #{url}"
    @logger.debug "body: #{body}"
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    headers = {'Content-Type' => 'application/oct-stream', 'Pragma' => "xz4BBcV#{@guid}", 'User-Agent' => USER_AGENT, 'Cookie' => "ssic=#{@ssic}", 'Connection' => 'Keep-Alive', 'Content-Length' => body.length.to_s}
    response = http.request_post(uri.request_uri, body, headers)

    @logger.debug "response: #{response.inspect}"
    @logger.debug "response body: #{response.body}"
    @logger.debug "fetion curl exec complete"
    response
  end

  def sip_create(fields, body='')
    sip = SIPC_HEADER + "\r\n"
    fields.each {|k, v| sip += "#{k}: #{v}\r\n"}
    sip += "Q: #{next_alive} R\r\n\r\n#{body}#{SIPP}"
    sip
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
    rsa_key.public_key

    response_str = rsa_key.public_encrypt(str).unpack("H*").first.upcase
  end
  
  def send_command
    @cat ? 'SendCatSMS' : 'SendSMS'
  end

  def self?(mobile_or_sid)
    mobile_or_sid == @mobile_no or mobile_or_sid == @sid
  end
end

