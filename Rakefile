require 'rubygems'
require 'rake'
require 'spec/rake/spectask'
require 'rake/rdoctask'
require 'jeweler'

desc 'Default: run unit tests.'
task :default => :spec

desc 'Generate documentation for the rfetion plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'rfetion'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc "Run all specs in spec directory"
Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_files = FileList['spec/**/*_spec.rb']
end

Jeweler::Tasks.new do |gemspec|
  gemspec.name = 'rfetion'
  gemspec.summary = 'rfetion is a ruby gem for China Mobile fetion service that you can send SMS free.'
  gemspec.description = 'rfetion is a ruby gem for China Mobile fetion service that you can send SMS free.'
  gemspec.email = 'flyerhzm@gmail.com'
  gemspec.homepage = 'http://github.com/flyerhzm/rfetion'
  gemspec.authors = ['Richard Huang']
  gemspec.files.exclude '.gitignore'
  gemspec.add_dependency 'guid'
  gemspec.add_dependency 'nokogiri'
  gemspec.add_dependency 'json'
  gemspec.add_dependency 'macaddr'
  gemspec.executables << 'rfetion'
end
Jeweler::GemcutterTasks.new
