require 'rubygems'
require 'uuid'
require 'net/http'
require 'net/https'
require 'rexml/document'

class Fetion
  include REXML

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
    doc = Document.new(response.body)
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
    puts @ssic
    puts @status_code
    puts @user_status
    puts @uri
    puts @mobile_no
    puts @user_id
    puts @sid
    puts @domain
  end

  def http_register
    nonce_regex = /nonce="(\w+)"/
    ok_regex = /OK/
    arg = '<args><device type="PC" version="44" client-version="3.2.0540" />'
    arg += '<caps value="simple-im;im-session;temp-group;personal-group" />'
    arg += '<events value="contact;permission;system-message;personal-group" />'
    arg += '<user-info attributes="all" /><presence><basic value="400" desc="" /></presence></args>'

    call = next_call
    curl_exec(next_url, @ssic, FETION_SIPP)
    msg = sip_create("R fetion.com.cn SIP-C/2.0", {'F' => @sid, 'I' => call, 'Q' => '1 R'}, arg) + FETION_SIPP
    puts msg
    curl_exec(next_url('i'), @ssic, msg)
    response = curl_exec(next_url, @ssic, FETION_SIPP)
    puts response.body
    unless response.body =~ nonce_regex
      puts "Fetion Error: no nonce found"
      return false
    end
    @nonce = $1
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

  def next_url(t = 's')
    @seq += 1
    FETION_URL + "?t=#{t}&i=#{@seq}"
  end

  def next_call
    @next_call += 1
    @next_call
  end
end

