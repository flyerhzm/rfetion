require 'rubygems'
require 'spec/autorun'
require 'mocha'
require 'fakeweb'

$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))
require 'rfetion'
FakeWeb.allow_net_connect = false
