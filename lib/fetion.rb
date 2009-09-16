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

  def login
    ssic_regex = /ssic=(.*);/
    sid_regex = /sip:(\d+)@(.+);/s
    cookie_file = "#{Time.now.strftime("%Y%m%d%H%M%S")}_cookie.text"
    return_val = false

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
    puts @ssic
    puts @status_code
    puts @user_status
    puts @uri
    puts @mobile_no
    puts @user_id
  end
end

