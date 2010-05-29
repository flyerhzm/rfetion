require File.dirname(__FILE__) + '/../spec_helper'

describe SipcMessage do
  class Fetion
    attr_accessor :mobile_no, :sid, :password, :status_code, :user_status, :uid, :ssic, :nonce, :key, :signature, :response, :call
  end

  before :each do
    @fetion = Fetion.new
    @fetion.sid = "730020377"
    @fetion.uid = "390937727"
    @fetion.mobile_no = "15800681509"
    @fetion.uri = "730020377@fetion.com.cn;p=6907"
    @fetion.response = "62E57A276EB9B7AAC233B8983A39941870CE74E3B2CD6480B5CA9DCF37C57DECEA250F261543CB4424EE9E72354C9F33C805EB9839BF96501D0261614E69BDF0DBDF484047750B3113DF8850FEF39428ADC17FE86E8800ED5A77AA7F6630F21AE8A24E6ECC2F003BF3B93E35051A7778D238F86D21581BC829679EBEAD36390F"
  end

  it "should get register first" do
    guid = hexdigest = ""
    Guid.stubs(:new).returns(guid)
    guid.stubs(:hexdigest).returns(hexdigest)
    hexdigest.stubs(:upcase).returns("19D28D4978125CAA4F6E54277BA7D9EF")
    @fetion.alive = 0
    sipc_message =<<-EOF
R fetion.com.cn SIP-C/4.0
F: 730020377
I: 1
Q: 1 R
CN: 19D28D4978125CAA4F6E54277BA7D9EF
CL: type="pc" ,version="3.6.2020"

SIPP
EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    SipcMessage.register_first(@fetion).should == sipc_message
  end

  it "should get register_second" do
    @fetion.alive = 1
    sipc_message =<<-EOF
R fetion.com.cn SIP-C/4.0
F: 730020377
I: 1
Q: 2 R
A: Digest response="62E57A276EB9B7AAC233B8983A39941870CE74E3B2CD6480B5CA9DCF37C57DECEA250F261543CB4424EE9E72354C9F33C805EB9839BF96501D0261614E69BDF0DBDF484047750B3113DF8850FEF39428ADC17FE86E8800ED5A77AA7F6630F21AE8A24E6ECC2F003BF3B93E35051A7778D238F86D21581BC829679EBEAD36390F",algorithm="SHA1-sess-v4"
AK: ak-value
L: 447

<args><device machine-code="B04B5DA2F5F1B8D01A76C0EBC841414C" /><caps value="ff" /><events value="7f" /><user-info mobile-no="15800681509" user-id="390937727"><personal version="0" attributes="v4default" /><custom-config version="0" /><contact-list version="0"   buddy-attributes="v4default" /></user-info><credentials domains="fetion.com.cn;m161.com.cn;www.ikuwa.cn;games.fetion.com.cn" /><presence><basic value="400" desc="" /></presence></args>SIPP
EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    @fetion.machine_code = "B04B5DA2F5F1B8D01A76C0EBC841414C"
    SipcMessage.register_second(@fetion).should == sipc_message
  end

  it "should get group list" do
    @fetion.call = 2
    sipc_message =<<-EOF
S fetion.com.cn SIP-C/4.0
F: 730020377
I: 3
Q: 1 S
N: PGGetGroupList
L: 54

<args><group-list attributes="name;identity" /></args>SIPP
EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    SipcMessage.get_group_list(@fetion).should == sipc_message
  end

  it "should presence" do
    @fetion.call = 3
    sipc_message =<<-EOF
SUB fetion.com.cn SIP-C/4.0
F: 730020377
I: 4
Q: 1 SUB
N: PresenceV4
L: 87

<args><subscription self="v4default;mail-count" buddy="v4default" version="0" /></args>SIPP
EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    SipcMessage.presence(@fetion).should == sipc_message
  end

  it "should get group topic" do
    @fetion.call = 4
    sipc_message =<<-EOF
S fetion.com.cn SIP-C/4.0
F: 730020377
I: 5
Q: 1 S
N: PGGetGroupTopic
L: 27

<args><topic-list /></args>SIPP
EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    SipcMessage.get_group_topic(@fetion).should == sipc_message
  end

  it "should get address list" do
    @fetion.call = 5
    sipc_message =<<-EOF
S fetion.com.cn SIP-C/4.0
F: 730020377
I: 6
Q: 1 S
N: GetAddressListV4
L: 37

<args><contacts version="0" /></args>SIPP
EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    SipcMessage.get_address_list(@fetion).should == sipc_message
  end

  it "should send cat sms" do
    @fetion.call = 8
    sipc_message =<<-EOF
M fetion.com.cn SIP-C/4.0
F: 730020377
I: 9
Q: 1 M
T: sip:730020377@fetion.com.cn;p=6907
N: SendCatSMS
L: 4

testSIPP
EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    SipcMessage.send_cat_sms(@fetion, 'sip:730020377@fetion.com.cn;p=6907', 'test').should == sipc_message
  end

  it "should send cat msg" do
    @fetion.call = 8
    sipc_message =<<-EOF
M fetion.com.cn SIP-C/4.0
F: 730020377
I: 9
Q: 2 M
T: sip:638993408@fetion.com.cn;p=2242
K: SaveHistory
N: CatMsg
L: 4

testSIPP
EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    SipcMessage.send_cat_msg(@fetion, 'sip:638993408@fetion.com.cn;p=2242', 'test').should == sipc_message
  end

  it "should set schedule sms" do
    @fetion.call = 8
    sipc_message =<<-EOF
S fetion.com.cn SIP-C/4.0
F: 730020377
I: 9
Q: 1 S
N: SSSetScheduleCatSms
SV: 1
L: 182

<args><schedule-sms send-time="2010-05-08 15:50:00" type="0"><message>test</message><receivers><receiver uri="sip:638993408@fetion.com.cn;p=2242" /></receivers></schedule-sms></args>SIPP
EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    SipcMessage.set_schedule_sms(@fetion, ['sip:638993408@fetion.com.cn;p=2242'], 'test', '2010-05-08 15:50:00').should == sipc_message
  end

  it "should get contact info" do
    @fetion.call = 10
    sipc_message =<<-EOF
S fetion.com.cn SIP-C/4.0
F: 730020377
I: 11
Q: 1 S
N: GetContactInfoV4
L: 46

<args><contact uri="tel:15800681507" /></args>SIPP
EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    SipcMessage.get_contact_info(@fetion, "tel:15800681507").should == sipc_message
  end

  it "should get contact info with sip" do
    @fetion.call = 10
    sipc_message =<<-EOF
S fetion.com.cn SIP-C/4.0
F: 730020377
I: 11
Q: 1 S
N: GetContactInfoV4
L: 65

<args><contact uri="sip:638993408@fetion.com.cn;p=2242" /></args>SIPP
EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    SipcMessage.get_contact_info(@fetion, "sip:638993408@fetion.com.cn;p=2242").should == sipc_message
  end

  it "should add buddy" do
    @fetion.call = 9
    @fetion.instance_variable_set(:@nickname, 'flyerhzm')
    sipc_message =<<-EOF
S fetion.com.cn SIP-C/4.0
F: 730020377
I: 10
Q: 1 S
N: AddBuddyV4
L: 175

<args><contacts><buddies><buddy uri="tel:13634102006" buddy-lists="" desc="flyerhzm" expose-mobile-no="1" expose-name="1" addbuddy-phrase-id="0" /></buddies></contacts></args>SIPP
EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    SipcMessage.add_buddy(@fetion, :friend_mobile => "13634102006").should == sipc_message

    @fetion.call = 9
    sipc_message =<<-EOF
S fetion.com.cn SIP-C/4.0
F: 730020377
I: 10
Q: 1 S
N: AddBuddyV4
L: 136

<args><contacts><buddies><buddy uri="sip:638993408" buddy-lists="" desc="flyerhzm" addbuddy-phrase-id="0" /></buddies></contacts></args>SIPP
EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    SipcMessage.add_buddy(@fetion, :friend_sip => "638993408").should == sipc_message
  end

  it "should create session" do
    http_response_body =<<-EOF
I 730020377 SIP-C/4.0
F: sip:638993408@fetion.com.cn;p=2242
I: -13
K: text/plain
K: text/html-fragment
K: multiparty
K: nudge
Q: 14 I
L: 21

s=session
m=message SIPP
EOF
    http_response_body.gsub!("\n", "\r\n").chomp!
    last_sipc_response = SipcMessage.sipc_response(http_response_body, @fetion)
    sipc_message =<<-EOF
SIP-C/4.0 200 OK
I: -13
Q: 14 I
F: sip:638993408@fetion.com.cn;p=2242
K: text/plain
K: text/html-fragment
K: multiparty
K: nudge
L: 129

v=0
o=-0 0 IN 127.0.0.1:8001
s=session
c=IN IP4 127.0.0.1:8001
t=0 0
m=message 8001 sip sip:730020377@fetion.com.cn;p=6907
SIPP
EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    SipcMessage.create_session(@fetion, last_sipc_response).should == sipc_message
  end

  it "shoud session connected" do
    http_response_body =<<-EOF
O 730020377 SIP-C/4.0
I: -13
Q: 2 O
K: text/plain
K: text/html-fragment
K: multiparty
K: nudge
F: sip:638993408@fetion.com.cn;p=2242

A 730020377 SIP-C/4.0
F: sip:638993408@fetion.com.cn;p=2242
I: -13
Q: 14 A

SIPP
EOF
    http_response_body.gsub!("\n", "\r\n").chomp!
    last_sipc_response = SipcMessage.sipc_response(http_response_body, @fetion)
    sipc_message =<<-EOF
SIP-C/4.0 200 OK
F: sip:638993408@fetion.com.cn;p=2242
I: -13
Q: 2 O
K: text/html-fragment
K: text/plain

SIPP
EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    SipcMessage.session_connected(@fetion, last_sipc_response).should == sipc_message
  end

  it "should msg_received" do
    http_response_body =<<-EOF
M 730020377 SIP-C/4.0
I: -13
Q: 4 M
F: sip:638993408@fetion.com.cn;p=2242
C: text/html-fragment
K: SaveHistory
L: 4
D: Sun, 16 May 2010 02:16:00 GMT
XI: 0dbdc4e81bff425dbcf8b591b497fe94

testSIPP
EOF
    http_response_body.gsub!("\n", "\r\n").chomp!
    sipc_message =<<-EOF
SIP-C/4.0 200 OK
F: sip:638993408@fetion.com.cn;p=2242
I: -13
Q: 4 M

SIPP
EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    SipcMessage.msg_received(@fetion, http_response_body).should == sipc_message
  end

  it "should keep alive" do
    @fetion.alive = 3
    sipc_message =<<-EOF
R fetion.com.cn SIP-C/4.0
F: 730020377
I: 1
Q: 4 R
N: KeepAlive
L: 97

<args><credentials domains="fetion.com.cn;m161.com.cn;www.ikuwa.cn;games.fetion.com.cn" /></args>SIPP
    EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    SipcMessage.keep_alive(@fetion).should == sipc_message
  end

  it "should close session" do
    @fetion.call = 5
    sipc_message =<<-EOF
B fetion.com.cn SIP-C/4.0
F: 730020377
I: 6
Q: 2 B
T: sip:638993408@fetion.com.cn;p=2242

SIPP
EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    SipcMessage.close_session(@fetion, "638993408@fetion.com.cn;p=2242").should == sipc_message
  end

  it "should logout" do
    @fetion.alive = 2
    sipc_message =<<-EOF
R fetion.com.cn SIP-C/4.0
F: 730020377
I: 1
Q: 3 R
X: 0

SIPP
EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    SipcMessage.logout(@fetion).should == sipc_message
  end

  it "should handle contact request" do
    @fetion.call = 8
    sipc_message =<<-EOF
S fetion.com.cn SIP-C/4.0
F: 730020377
I: 9
Q: 1 S
N: HandleContactRequestV4
L: 186

<args><contacts><buddies><buddy user-id="295098062" uri="sip:638993408@fetion.com.cn;p=2242" result="1" buddy-lists="" expose-mobile-no="0" expose-name="0" /></buddies></contacts></args>SIPP
    EOF
    sipc_message.gsub!("\n", "\r\n").chomp!
    contact = Fetion::Contact.new
    contact.uid = '295098062'
    contact.uri = 'sip:638993408@fetion.com.cn;p=2242'
    SipcMessage.handle_contact_request(@fetion, contact, :result => "1").should == sipc_message
  end
end
