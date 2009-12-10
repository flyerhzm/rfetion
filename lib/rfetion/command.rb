require 'optparse'

options = {}

OptionParser.new do |opts|
  # Set a banner, displayed at the top of the help screen.
  opts.banner = "Usage: rfetion [options]"

  opts.separator ""
  opts.separator <<-EOF
    Example: rfetion -m mobile -p password -c sms_content
             rfetion -m mobile -p password -r mobile_or_fetion_numbers -c sms_content
             rfetion -m mobile -p password -r mobile_or_fetion_numbers -c sms_content -t time
             rfetion -m mobile -p password --add-buddy-with-mobile friend_mobile
             rfetion -m mobile -p password --add-buddy-with-sip friend_sip
             
  EOF

  opts.on('-m', '--mobile MOBILE', 'Fetion mobile number') do |mobile|
    options[:mobile_no] = mobile
  end

  opts.on('-p', '--password PASSWORD', 'Fetion password') do |password|
    options[:password] = password
  end

  opts.on('-c', '--content CONTENT', 'Fetion message content') do |content|
    options[:content] = content
  end

  opts.on('-r', '--receivers MOBILE,SIP', Array, "(optional) Receivers' Fetion mobile numbers or fetion sip numbers, if no recievers, send sms to yourself") do |receivers|
    options[:receivers] = receivers
  end

  opts.on('-t', '--time TIME', 'Schedule time to send sms, format is "2009-12-10 20:00:00"') do |time|
    options[:time] = time
  end

  opts.on('--add-buddy-with-mobile MOBILE', 'Add friend mobile as fetion friend') do |mobile|
    options[:add_mobile] = mobile
  end

  opts.on('--add-buddy-with-sip SIP', 'Add friend fetion sip as fetion friend') do |sip|
    options[:add_sip] = sip
  end

  opts.separator ""
  opts.separator "different mode:"

  opts.on('--debug', 'debug mode') do
    options[:debug] = true
  end

  opts.on('--silence', 'silence mode') do
    options[:silence] = true
  end

  opts.separator ""
  opts.separator "Common options:"

  opts.on_tail('-v', '--version', 'Show this version') do
    puts File.read(File.dirname(__FILE__) + '/../../VERSION')
    exit
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end

  opts.parse!
end

def level(options)
  return Logger::DEBUG if options[:debug]
  return Logger::ERROR if options[:silence]
  return Logger::INFO
end

begin
  if options[:add_mobile] or options[:add_sip]
    raise FetionException.new('You must input your mobile number and password') unless options[:mobile_no] and options[:password]
    Fetion.add_buddy_with_mobile(options[:mobile_no], options[:password], options[:add_mobile], level(options)) if options[:add_mobile]
    Fetion.add_buddy_with_sip(options[:mobile_no], options[:password], options[:add_sip], level(options)) if options[:add_sip]
    exit
  end
  
  raise FetionException.new('You must input your mobile number, password and content') unless options[:mobile_no] and options[:password] and options[:content]
  if options[:time]
    Fetion.schedule_sms(options[:mobile_no], options[:password], options[:receivers], options[:content], options[:time], level(options))
  else
    Fetion.send_sms(options[:mobile_no], options[:password], options[:receivers], options[:content], level(options))
  end
rescue FetionException => e
  puts e.message
  puts "Please use 'rfetion -h' to get more details"
end
