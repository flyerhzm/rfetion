require 'optparse'

options = {}

OptionParser.new do |opts|
  # Set a banner, displayed at the top of the help screen.
  opts.banner = "Usage: rfetion [options]"

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

  opts.parse!
end

if options[:mobile_no] and options[:password] and options[:content]
  if options[:friends_mobile].empty?
    Fetion.send_sms_to_self(options[:mobile_no], options[:password], options[:content])
  else
    Fetion.send_sms_to_friends(options[:mobile_no], options[:password], options[:friends_mobile], options[:content])
  end
end
