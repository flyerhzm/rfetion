require 'optparse'

options = {}

OptionParser.new do |opts|
  # Set a banner, displayed at the top of the help screen.
  opts.banner = "Usage: rfetion [options]"

  opts.separator ""
  opts.separator <<EOF
    Example: rfetion -m mobile -p password -f friend_mobile -c sms_content
             rfetion -m mobile -p password -a friend_mobile
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

  options[:friends_mobile] = []
  opts.on('-f', '--friends MOBILE1,MOBILE2', Array, '(optional) Fetion friends mobile number, if no friends mobile number, send message to yourself') do |f|
    options[:friends_mobile] = f
  end

  opts.on('-a', '--add_buddy MOBILE', 'Add friend mobile as fetion friend') do |f|
    options[:add_mobile] = f
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
  if options[:add_mobile]
    raise FetionException.new('You must input your mobile number and password') unless options[:mobile_no] and options[:password]
    Fetion.add_buddy(options[:mobile_no], options[:password], options[:add_mobile], level(options))
    exit
  end
  
  raise FetionException.new('You must input your mobile number, password and content') unless options[:mobile_no] and options[:password] and options[:content]
  if options[:friends_mobile].empty?
    Fetion.send_sms_to_self(options[:mobile_no], options[:password], options[:content], level(options))
  else
    Fetion.send_sms_to_friends(options[:mobile_no], options[:password], options[:friends_mobile], options[:content], level(options))
  end
rescue FetionException => e
  puts e.message
  puts "Please use 'rfetion -h' to get more details"
end
