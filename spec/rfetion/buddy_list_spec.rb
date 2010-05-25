require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Fetion::BuddyList do
  before :each do
    @buddy_list = Fetion::BuddyList.new("1", "My friend")
    @buddy_list.add_contact(Fetion::Contact.new(:uid => "226911221", :uri => "sip:572512981@fetion.com.cn;p=3544", :bid => "1", :status => "400"))
    @buddy_list.add_contact(Fetion::Contact.new(:uid => "295098062", :uri => "sip:638993408@fetion.com.cn;p=2242", :bid => "1"))
    @buddy_list.add_contact(Fetion::Contact.new(:uid => "579113578", :uri => "sip:838271744@fetion.com.cn;p=4805", :bid => "1"))
    @buddy_list.add_contact(Fetion::Contact.new(:uid => "665046562", :uri => "sip:926157269@fetion.com.cn;p=12906", :bid => "1", :status => "400"))
    @buddy_list.add_contact(Fetion::Contact.new(:uid => "687455743", :uri => "sip:881033150@fetion.com.cn;p=5493", :bid => "1"))
    @buddy_list.add_contact(Fetion::Contact.new(:uid => "714355089", :uri => "sip:973921799@fetion.com.cn;p=12193", :bid => "1", :status => "400"))
    @buddy_list.add_contact(Fetion::Contact.new(:uid => "732743291", :uri => "sip:480867781@fetion.com.cn;p=16105", :bid => "1"))
  end

  it "should get total contacts count" do
    @buddy_list.total_contacts_count.should == 7
  end

  it "should get online contacts count" do
    @buddy_list.online_contacts_count.should == 3
  end

  it "should to_json" do
    buddy_list_json = @buddy_list.to_json
    p buddy_list_json
    buddy_list_json.should be_include %Q|"bid":"1"|
    buddy_list_json.should be_include %Q|"name":"My friend"|
    buddy_list_json.should be_include %Q|"total_contacts":7|
    buddy_list_json.should be_include %Q|"online_contacts":3|
  end
end
