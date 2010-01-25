require 'rubygems'
require 'guid'
require 'time'
require 'net/http'
require 'net/https'
require 'rexml/document'
require 'digest/sha1'
require 'digest/md5'
require 'logger'

class FetionException < Exception
end

class Fetion
  attr_accessor :mobile_no, :sid, :password
  attr_reader :uri, :contacts

  FETION_URL = 'http://221.130.44.194/ht/sd.aspx'
  FETION_LOGIN_URL = 'https://uid.fetion.com.cn/ssiportal/SSIAppSignIn.aspx'
  FETION_CONFIG_URL = 'http://nav.fetion.com.cn/nav/getsystemconfig.aspx'
  FETION_SIPP = 'SIPP'
  @nonce = nil

  def initialize
    @next_call = 0
    @seq = 0
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
      uri = URI.parse(FETION_LOGIN_URL + "?mobileno=#{@mobile_no}&pwd=#{@password}")
    else
      uri = URI.parse(FETION_LOGIN_URL + "?sid=#{@sid}&pwd=#{@password}")
    end
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    headers = {'Content-Type' => 'application/oct-stream', 'Pragma' => "xz4BBcV#{@guid}", 'User-Agent' => 'IIC2.0/PC 3.2.0540'}
    response = http.request_get(uri.request_uri, headers)

    raise FetionException.new('Fetion Error: Login failed.') unless response.is_a? Net::HTTPSuccess
    raise FetionException.new('Fetion Error: No ssic found in cookie.') unless response['set-cookie'] =~ /ssic=(.*);/

    @ssic = $1
    @logger.debug response.body
    doc = REXML::Document.new(response.body)
    results = doc.root
    @status_code = results.attributes["status-code"]
    user = results.children.first
    @user_status = user.attributes['user-status']
    @uri = user.attributes['uri']
    @mobile_no = user.attributes['mobile-no']
    @user_id = user.attributes['user-id']
    if @uri =~ /sip:(\d+)@(.+);/
      @sid = $1
      @domain = $2
    end
    @logger.debug "ssic: " + @ssic
    @logger.debug "status_code: " + @status_code
    @logger.debug "user_status: " + @user_status
    @logger.debug "uri: " + @uri
    @logger.debug "mobile_no: " + @mobile_no
    @logger.debug "user_id: " + @user_id
    @logger.debug "sid: " + @sid
    @logger.debug "domain: " + @domain
    @logger.info "fetion login success"
  end

  def register
    @logger.info "fetion http register"
    call = next_call
    arg = '<args><device type="PC" version="284571220" client-version="3.3.0370" /><caps value="simple-im;im-session;temp-group;personal-group" /><events value="contact;permission;system-message;personal-group" /><user-info attributes="all" /><presence><basic value="400" desc="" /></presence></args>'

    # get nonce, it failed, try again 16s later
    begin
      register_first(call, arg)
    rescue FetionException
      sleep 16
      register_first(call, arg)
    end

    begin
      register_second(call, arg)
    rescue FetionException
      sleep 16
      register_second(call, arg)
    end
    @logger.info "fetion http register success"
  end

  def register_first(call, arg)
    @logger.debug "fetion http register first"

    curl_exec(next_url, @ssic, FETION_SIPP)

    msg = sip_create("R fetion.com.cn SIP-C/2.0", {'F' => @sid, 'I' => call, 'Q' => '1 R'}, arg) + FETION_SIPP
    curl_exec(next_url('i'), @ssic, msg)

    response = curl_exec(next_url, @ssic, FETION_SIPP)
    raise FetionException.new("Fetion Error: no nonce found") unless response.body =~ /nonce="(\w+)"/
      
    @nonce = $1
    @salt =  "777A6D03"
    @cnonce = calc_cnonce
    @response = calc_response

    @logger.debug "nonce: #{@nonce}"
    @logger.debug "salt: #{@salt}"
    @logger.debug "cnonce: #{@cnonce}"
    @logger.debug "response: #{@response}"
    @logger.debug "fetion http register first success"
  end

  def register_second(call, arg)
    @logger.debug "fetion http register second"

    msg = sip_create('R fetion.com.cn SIP-C/2.0', {'F' => @sid, 'I' => call, 'Q' => '2 R', 'A' => "Digest algorithm=\"SHA1-sess\",response=\"#{@response}\",cnonce=\"#{@cnonce}\",salt=\"#{@salt}\""}, arg) + FETION_SIPP
    curl_exec(next_url, @ssic, msg)
    response = curl_exec(next_url, @ssic, FETION_SIPP)

    raise FetionException.new('Fetion Error: Register failed.') unless response.is_a? Net::HTTPSuccess
    @logger.debug "fetion http register second success"
  end

  def get_buddy_list
    @logger.info "fetion get buddy list"
    arg = '<args><contacts><buddy-lists /><buddies attributes="all" /><mobile-buddies attributes="all" /><chat-friends /><blacklist /><allow-list /></contacts></args>'
    msg = sip_create('S fetion.com.cn SIP-C/2.0', {'F' => @sid, 'I' => next_call, 'Q' => '1 S', 'N' => 'GetContactList'}, arg) + FETION_SIPP
    curl_exec(next_url, @ssic, msg)
    response = curl_exec(next_url, @ssic, FETION_SIPP)
    raise FetionException.new("Fetion Error: Get buddy list error") unless response.is_a? Net::HTTPSuccess

    response.body.scan(%r{<results>.*?</results>}).each do |results|
      doc = REXML::Document.new(results)
      doc.elements.each("results/contacts/allow-list/contact") do |contact|
        @buddies << {:uri => contact.attributes["uri"]}
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
      doc = REXML::Document.new(results)
      doc.elements.each("results/contacts/contact") do |contact|
        attrs = contact.children.size == 0 ? {} : contact.children.first.attributes
        @contacts << Contact.new(contact.attributes["uri"], attrs)
      end
    end
    @logger.debug @contacts.inspect
    @logger.info "fetion get contacts info success"
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

    doc = REXML::Document.new(response.body.chomp(FETION_SIPP))
    doc.elements.each('results/personal') do |person|
      @person = person.attributes
    end
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

  def curl_exec(url, ssic, body)
    @logger.debug "fetion curl exec"
    @logger.debug "url: #{url}"
    @logger.debug "ssic: #{ssic}"
    @logger.debug "body: #{body}"
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    headers = {'Content-Type' => 'application/oct-stream', 'Pragma' => "xz4BBcV#{@guid}", 'User-Agent' => 'IIC2.0/PC 3.2.0540', 'Cookie' => "ssic=#{@ssic}"}
    response = http.request_post(uri.request_uri, body, headers)

    @logger.debug "response: #{response.inspect}"
    @logger.debug "response body: #{response.body}"
    @logger.debug "fetion curl exec complete"
    response
  end

  def sip_create(invite, fields, arg)
    sip = invite + "\r\n"
    fields.each {|k, v| sip += "#{k}: #{v}\r\n"}
    sip += "L: #{arg.size}\r\n\r\n#{arg}"
    @logger.debug "sip message: #{sip}"
    sip
  end

  def calc_response
    str = [hash_password[8..-1]].pack("H*")
    key = Digest::SHA1.digest("#{@sid}:#{@domain}:#{str}")

    h1 = Digest::MD5.hexdigest("#{key}:#{@nonce}:#{@cnonce}").upcase
    h2 = Digest::MD5.hexdigest("REGISTER:#{@sid}").upcase
    
    Digest::MD5.hexdigest("#{h1}:#{@nonce}:#{h2}").upcase
  end

  def calc_cnonce
    Digest::MD5.hexdigest(@guid).upcase
  end

  def hash_password
    salt = "#{0x77.chr}#{0x7A.chr}#{0x6D.chr}#{0x03.chr}"
    src = salt + Digest::SHA1.digest(@password)
    '777A6D03' + Digest::SHA1.hexdigest(src).upcase
  end

  def next_url(t = 's')
    @seq += 1
    FETION_URL + "?t=#{t}&i=#{@seq}"
  end

  def next_call
    @next_call += 1
  end
  
  def send_command
    @cat ? 'SendCatSMS' : 'SendSMS'
  end

  def self?(mobile_or_sid)
    mobile_or_sid == @mobile_no or mobile_or_sid == @sid
  end
end

