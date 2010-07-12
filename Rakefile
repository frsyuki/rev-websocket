require 'rake'

begin
	require 'jeweler'
	Jeweler::Tasks.new do |gemspec|
		gemspec.name = "rev-websocket"
		gemspec.summary = "WebSocket server based on Rev"
		gemspec.description = gemspec.summary
		gemspec.email = "frsyuki@users.sourceforge.jp"
		gemspec.homepage = "http://github.com/frsyuki/rev-websocket"
		gemspec.authors = ["FURUHASHI Sadayuki"]
		gemspec.add_dependency("rev", ">= 0.3.2")
		gemspec.add_dependency("thin", '>= 1.2.7')
	end
	Jeweler::GemcutterTasks.new
rescue LoadError
	puts "Jeweler not available. Install it with: gem install jeweler"
end

task :default => :build

