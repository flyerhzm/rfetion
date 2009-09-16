require 'rubygems'
require 'uuid'
require 'net/http'
require 'net/https'
require 'rexml/document'
require 'digest/sha1'

class Fetion
  attr_accessor :user_mobile, :password, :sendto_sid, :content
  attr_accessor :fetion_proxy, :fetion_debug

  FETION_URL = 'http://221.130.44.194/ht/sd.aspx'
  FETION_LOGIN_URL = 'https://nav.fetion.com.cn/ssiportal/SSIAppSignIn.aspx'
  FETION_CONFIG_URL = 'http://nav.fetion.com.cn/nav/getsystemconfig.aspx'
  FETION_SIPP = 'SIPP'
  GUID = UUID.new.generate

  def initialize
    @next_call = 0
    @seq = 0
    @buddies = []
  end

  def login
    ssic_regex = /ssic=(.*);/
    sid_regex = /sip:(\d+)@(.+);/s

    uri = URI.parse(FETION_LOGIN_URL + "?mobileno=#{@user_mobile}&pwd=#{@password}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    headers = {'Content-Type' => 'application/oct-stream', 'Pragma' => "xz4BBcV#{GUID}", 'User-Agent' => 'IIC2.0/PC 3.2.0540'}
    response = http.request_get(uri.request_uri, headers)

    unless response.is_a? Net::HTTPSuccess
      puts "login failed"
      return false
    end

    unless response['set-cookie'] =~ ssic_regex
      puts "Fetion Error: No ssic found in cookie"
      return false
    end

    @ssic = $1
    doc = REXML::Document.new(response.body)
    results = doc.root
    @status_code = results.attributes["status-code"]
    user = results.children.first
    @user_status = user.attributes['user-status']
    @uri = user.attributes['uri']
    @mobile_no = user.attributes['mobile-no']
    @user_id = user.attributes['user-id']
    if @uri =~ sid_regex
      @sid = $1
      @domain = $2
    end
    puts "ssic: " + @ssic
    puts "status_code: " + @status_code
    puts "user_status: " + @user_status
    puts "uri: " + @uri
    puts "mobile_no: " + @mobile_no
    puts "user_id: " + @user_id
    puts "sid: " + @sid
    puts "domain: " + @domain
  end

  def http_register
    nonce_regex = /nonce="(\w+)"/
    arg = '<args><device type="PC" version="44" client-version="3.2.0540" /><caps value="simple-im;im-session;temp-group;personal-group" /><events value="contact;permission;system-message;personal-group" /><user-info attributes="all" /><presence><basic value="400" desc="" /></presence></args>'

    call = next_call
    puts "first: " + curl_exec(next_url, @ssic, FETION_SIPP).body

    msg = sip_create("R fetion.com.cn SIP-C/2.0", {'F' => @sid, 'I' => call, 'Q' => '1 R'}, arg) + FETION_SIPP
    puts "second: " + curl_exec(next_url('i'), @ssic, msg).body

    response = curl_exec(next_url, @ssic, FETION_SIPP)
    puts "third: " + response.body
    unless response.body =~ nonce_regex
      puts "Fetion Error: no nonce found"
      return false
    end
    @nonce = $1
    @salt =  "777A6D03"
    @cnonce = calc_cnonce
    @response = calc_response
    puts "nonce: #{@nonce}"
    puts "salt: #{@salt}"
    puts "cnonce: #{@cnonce}"
    puts "response: #{@response}"

    msg = sip_create('R fetion.com.cn SIP-C/2.0', {'F' => @sid, 'I' => call, 'Q' => '2 R', 'A' => "Digest algorithm=\"SHA1-sess\",response=\"#{@response}\",cnonce=\"#{@cnonce}\",salt=\"#{@salt}\""}, arg) + FETION_SIPP
    curl_exec(next_url, @ssic, msg)
    response = curl_exec(next_url, @ssic, FETION_SIPP)
    response.is_a? Net::HTTPSuccess
  end

  def get_buddy_list
    buddy_regex = /.*?\r\n\r\n(.*)#{FETION_SIPP}\s*$/i
    arg = '<args><contacts><buddy-lists /><buddies attributes="all" /><mobile-buddies attributes="all" /><chat-friends /><blacklist /></contacts></args>'
    msg = sip_create('S fetion.com.cn SIP-C/2.0', {'F' => @sid, 'I' => next_call, 'Q' => '1 S', 'N' => 'GetContactList'}, arg) + FETION_SIPP
    curl_exec(next_url, @ssic, msg)
    response = curl_exec(next_url, @ssic, FETION_SIPP)
    unless response.body =~ buddy_regex
      puts "Fetion Error: No buddy list found"
      return false
    end
    doc = REXML::Document.new($1)
    doc.elements.each("//buddies/buddy") do |buddy|
      @buddies << buddy.attributes
    end
    doc.elements.each("//mobile-buddies/mobile-buddy") do |buddy|
      @buddies << buddy.attributes
    end
    puts @buddies.inspect
  end

  def curl_exec(url, ssic, body)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    headers = {'Content-Type' => 'application/oct-stream', 'Pragma' => "xz4BBcV#{GUID}", 'User-Agent' => 'IIC2.0/PC 3.2.0540', 'Cookie' => "ssic=#{@ssic}"}
    response = http.request_post(uri.request_uri, body, headers)
    response
  end

  def sip_create(invite, fields, arg)
    sip = invite + "\r\n"
    fields.each {|k, v| sip += "#{k}: #{v}\r\n"}
    sip += "L: #{arg.size}\r\n\r\n#{arg}"
    sip
  end

  def calc_response
    puts "hash_password: " + hash_password
    str = [hash_password[8..-1]].pack("H*")
    puts "str: " + str
    puts "#{@sid}:#{@domain}:#{str}"
    key = Digest::SHA1.digest("#{@sid}:#{@domain}:#{str}")
    puts "key: " + key

    puts "#{key}:#{@nonce}:#{@cnonce}"
    h1 = Digest::MD5.hexdigest("#{key}:#{@nonce}:#{@cnonce}").upcase
    puts "h1: " + h1
    h2 = Digest::MD5.hexdigest("REGISTER:#{@sid}").upcase
    puts "h2: " + h2
    
    Digest::MD5.hexdigest("#{h1}:#{@nonce}:#{h2}").upcase
  end

  def calc_cnonce
    Digest::MD5.hexdigest(UUID.new.generate).upcase
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
    @next_call
  end
end

