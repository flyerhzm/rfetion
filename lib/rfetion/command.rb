require 'optparse'

options = {}

OptionParser.new do |opts|
  # Set a banner, displayed at the top of the help screen.
  opts.banner = "Usage: rfetion [options]"

  opts.separator ""
  opts.separator <<-EOF
    Example: rfetion -m mobile -p password -c sms_content
             rfetion -s sip -p password -c sms_content
             rfetion -m mobile -p password -r mobile_or_fetion_numbers -c sms_content
             rfetion -m mobile -p password -r mobile_or_fetion_numbers -c sms_content -t time
             rfetion -m mobile -p password --add-buddy-with-mobile friend_mobile
             rfetion -s sip -p password --add-buddy-with-mobile friend_mobile
             rfetion -m mobile -p password --add-buddy-with-sip friend_sip
             
  EOF

  opts.on('-m', '--mobile MOBILE', 'Fetion mobile number') do |mobile|
    options[:mobile_no] = mobile
  end

  opts.on('-s', '--sip FETION_SIP', 'Fetion sid number') do |sid|
    options[:sid] = sid
  end

  opts.on('-p', '--password PASSWORD', 'Fetion password') do |password|
    options[:password] = password
  end

  opts.on('-c', '--content CONTENT', 'Fetion message content') do |content|
    options[:content] = content
  end

  opts.on('-r', '--receivers MOBILE,SIP', Array, "Receivers' Fetion mobile numbers or fetion sip numbers, if no recievers, send sms to yourself") do |receivers|
    options[:receivers] = receivers
  end

  opts.on('-t', '--time TIME', 'Schedule time to send sms, format is "2009-12-10 20:00:00"') do |time|
    options[:time] = time
  end

  opts.on('--add-buddy-with-mobile MOBILE', 'Add friend mobile as fetion friend') do |mobile|
    options[:friend_mobile] = mobile
  end

  opts.on('--add-buddy-with-sip SIP', 'Add friend fetion sip as fetion friend') do |sip|
    options[:friend_sip] = sip
  end

  opts.separator ""
  opts.separator "different mode:"

  opts.on('--debug', 'debug mode') do
    options[:logger_level] = Logger::DEBUG
  end

  opts.on('--silence', 'silence mode') do
    options[:logger_level] = Logger::ERROR
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

begin
  if options[:friend_mobile] or options[:friend_sip]
    raise FetionException.new('You must input your mobile number or fetion sid, and password') unless (options[:mobile_no] or options[:sid]) and options[:password]
    Fetion.add_buddy(options)
    exit
  end
  
  raise FetionException.new('You must input your mobile number or fetion sid, password and content') unless (options[:mobile_no] or options[:sid]) and options[:password] and options[:content]
  if options[:time]
    Fetion.schedule_sms(options)
  else
    Fetion.send_sms(options)
  end
rescue FetionException => e
  puts e.message
  puts "Please use 'rfetion -h' to get more details"
end
