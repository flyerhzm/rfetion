require 'optparse'

options = {}

OptionParser.new do |opts|
  # Set a banner, displayed at the top of the help screen.
  opts.banner = "Usage: rfetion [options]"

  opts.separator ""
  opts.separator <<-EOF
    Example: rfetion -m mobile -p password -f friends_mobile_or_fetion_number -c sms_content
             rfetion -m mobile -p password --add-buddy-with-mobile friend_mobile
             rfetion -m mobile -p password --add-buddy-with-sip friend_sip
  EOF

  opts.on('-m', '--mobile MOBILE', 'Fetion mobile number') do |mobile|
    options[:mobile_no] = mobile
  end

  opts.on('-p', '--password PASSWORD', 'Fetion password') do |f|
    options[:password] = f
  end

  opts.on('-c', '--content CONTENT', 'Fetion message content') do |f|
    options[:content] = f
  end

  options[:friends] = []
  opts.on('-f', '--friends MOBILE,FETION', Array, '(optional) Fetion friends mobile number or fetion number, if no friends mobile number and fetion number, send message to yourself') do |f|
    options[:friends] = f
  end

  opts.on('--add-buddy-with-mobile MOBILE', 'Add friend mobile as fetion friend') do |f|
    options[:add_mobile] = f
  end

  opts.on('--add-buddy-with-sip SIP', 'Add friend fetion sip as fetion friend') do |f|
    options[:add_sip] = f
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
  if options[:friends].empty?
    Fetion.send_sms_to_self(options[:mobile_no], options[:password], options[:content], level(options))
  else
    Fetion.send_sms_to_friends(options[:mobile_no], options[:password], options[:friends], options[:content], level(options))
  end
rescue FetionException => e
  puts e.message
  puts "Please use 'rfetion -h' to get more details"
end
