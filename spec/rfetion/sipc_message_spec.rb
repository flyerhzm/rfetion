require File.dirname(__FILE__) + '/../spec_helper'

describe SipcMessage do
  class Fetion
    attr_accessor :mobile_no, :sid, :password, :status_code, :user_status, :user_id, :ssic, :nonce, :key, :signature, :response, :call
  end

  before :each do
    @fetion = Fetion.new
    @fetion.sid = "730020377"
    @fetion.user_id = "390937727"
    @fetion.mobile_no = "15800681509"
    @fetion.response = "62E57A276EB9B7AAC233B8983A39941870CE74E3B2CD6480B5CA9DCF37C57DECEA250F261543CB4424EE9E72354C9F33C805EB9839BF96501D0261614E69BDF0DBDF484047750B3113DF8850FEF39428ADC17FE86E8800ED5A77AA7F6630F21AE8A24E6ECC2F003BF3B93E35051A7778D238F86D21581BC829679EBEAD36390F"
  end

  it "should get register first" do
    guid = hexdigest = ""
    Guid.stubs(:new).returns(guid)
    guid.stubs(:hexdigest).returns(hexdigest)
    hexdigest.stubs(:upcase).returns("19D28D4978125CAA4F6E54277BA7D9EF")
    sipc_message = %Q|R fetion.com.cn SIP-C/4.0\r\nF: 730020377\r\nI: 1\r\nQ: 1 R\r\nCN: 19D28D4978125CAA4F6E54277BA7D9EF\r\nCL: type="pc" ,version="3.6.2020"\r\n\r\nSIPP|
    SipcMessage.register_first(@fetion).should == sipc_message
  end

  it "should get register_second" do
    sipc_message = %Q|R fetion.com.cn SIP-C/4.0\r\nF: 730020377\r\nI: 1\r\nQ: 2 R\r\nA: Digest response="62E57A276EB9B7AAC233B8983A39941870CE74E3B2CD6480B5CA9DCF37C57DECEA250F261543CB4424EE9E72354C9F33C805EB9839BF96501D0261614E69BDF0DBDF484047750B3113DF8850FEF39428ADC17FE86E8800ED5A77AA7F6630F21AE8A24E6ECC2F003BF3B93E35051A7778D238F86D21581BC829679EBEAD36390F",algorithm="SHA1-sess-v4"\r\nAK: ak-value\r\nL: 447\r\n\r\n<args><device machine-code="B04B5DA2F5F1B8D01A76C0EBC841414C" /><caps value="ff" /><events value="7f" /><user-info mobile-no="15800681509" user-id="390937727"><personal version="0" attributes="v4default" /><custom-config version="0" /><contact-list version="0"   buddy-attributes="v4default" /></user-info><credentials domains="fetion.com.cn;m161.com.cn;www.ikuwa.cn;games.fetion.com.cn" /><presence><basic value="400" desc="" /></presence></args>SIPP|
    SipcMessage.register_second(@fetion).should == sipc_message
  end

  it "should get group list" do
    @fetion.call = 2
    sipc_message = %Q|S fetion.com.cn SIP-C/4.0\r\nF: 730020377\r\nI: 3\r\nQ: 1 S\r\nN: PGGetGroupList\r\nL: 54\r\n\r\n<args><group-list attributes="name;identity" /></args>SIPP|
    SipcMessage.get_group_list(@fetion).should == sipc_message
  end

  it "should presence" do
    @fetion.call = 3
    sipc_message = %Q|SUB fetion.com.cn SIP-C/4.0\r\nF: 730020377\r\nI: 4\r\nQ: 1 SUB\r\nN: PresenceV4\r\nL: 87\r\n\r\n<args><subscription self="v4default;mail-count" buddy="v4default" version="0" /></args>SIPP|
    SipcMessage.presence(@fetion).should == sipc_message
  end

  it "should get group topic" do
    @fetion.call = 4
    sipc_message = %Q|S fetion.com.cn SIP-C/4.0\r\nF: 730020377\r\nI: 5\r\nQ: 1 S\r\nN: PGGetGroupTopic\r\nL: 27\r\n\r\n<args><topic-list /></args>SIPP|
    SipcMessage.get_group_topic(@fetion).should == sipc_message
  end

  it "should get address list" do
    @fetion.call = 5
    sipc_message = %Q|S fetion.com.cn SIP-C/4.0\r\nF: 730020377\r\nI: 6\r\nQ: 1 S\r\nN: GetAddressListV4\r\nL: 37\r\n\r\n<args><contacts version="0" /></args>SIPP|
    SipcMessage.get_address_list(@fetion).should == sipc_message
  end

  it "should send cat sms" do
    @fetion.call = 8
    sipc_message = %Q|M fetion.com.cn SIP-C/4.0\r\nF: 730020377\r\nI: 9\r\nQ: 1 M\r\nT: sip:730020377@fetion.com.cn;p=6907\r\nN: SendCatSMS\r\nL: 4\r\n\r\ntestSIPP|
    SipcMessage.send_cat_sms(@fetion, 'sip:730020377@fetion.com.cn;p=6907', 'test').should == sipc_message
  end

  it "should send msg" do
    @fetion.call = 8
    sipc_message = %Q|M fetion.com.cn SIP-C/4.0\r\nF: 730020377\r\nI: 9\r\nQ: 3 M\r\nT: sip:638993408@fetion.com.cn;p=2242\r\nK: SaveHistory\r\nL: 4\r\n\r\ntestSIPP|
    SipcMessage.send_msg(@fetion, 'sip:638993408@fetion.com.cn;p=2242', 'test').should == sipc_message
  end

  it "should set schedule sms" do
    @fetion.call = 8
    sipc_message = %Q|S fetion.com.cn SIP-C/4.0\r\nF: 730020377\r\nI: 9\r\nQ: 1 S\r\nN: SSSetScheduleCatSms\r\nSV: 1\r\nL: 182\r\n\r\n<args><schedule-sms send-time="2010-05-08 15:50:00" type="0"><message>test</message><receivers><receiver uri="sip:638993408@fetion.com.cn;p=2242" /></receivers></schedule-sms></args>SIPP|
    SipcMessage.set_schedule_sms(@fetion, ['sip:638993408@fetion.com.cn;p=2242'], 'test', '2010-05-08 15:50:00').should == sipc_message
  end

  it "should add buddy" do
    @fetion.call = 9
    @fetion.instance_variable_set(:@nickname, 'flyerhzm')
    sipc_message = %Q|S fetion.com.cn SIP-C/4.0\r\nF: 730020377\r\nI: 10\r\nQ: 1 S\r\nN: AddBuddyV4\r\nL: 175\r\n\r\n<args><contacts><buddies><buddy uri="tel:13634102006" buddy-lists="" desc="flyerhzm" expose-mobile-no="1" expose-name="1" addbuddy-phrase-id="0" /></buddies></contacts></args>SIPP|
    SipcMessage.add_buddy(@fetion, :friend_mobile => "13634102006").should == sipc_message

    @fetion.call = 9
    sipc_message = %Q|S fetion.com.cn SIP-C/4.0\r\nF: 730020377\r\nI: 10\r\nQ: 1 S\r\nN: AddBuddyV4\r\nL: 136\r\n\r\n<args><contacts><buddies><buddy uri="sip:638993408" buddy-lists="" desc="flyerhzm" addbuddy-phrase-id="0" /></buddies></contacts></args>SIPP|
    SipcMessage.add_buddy(@fetion, :friend_sip => "638993408").should == sipc_message
  end

  it "should logout" do
    sipc_message = %Q|R fetion.com.cn SIP-C/4.0\r\nF: 730020377\r\nI: 1\r\nQ: 3 R\r\nX: 0\r\n\r\nSIPP|
    SipcMessage.logout(@fetion).should == sipc_message
  end
end
