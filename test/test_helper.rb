require 'rubygems'
gem 'minitest' # ensures you're using the gem, and not the built in MT
require 'minitest/autorun'
require 'bundler/setup'
require 'minitest/unit'

$dir = File.dirname(File.expand_path(__FILE__))
$LOAD_PATH.unshift $dir + '/../lib'
require 'resque_jobs_tree'
$TESTING = true

Resque.inline = true

class Model
  def id
    @id ||= rand 1000
  end
  def self.find id
    'stubed_instance'
  end
end

# Run resque callbacks in inline mode
class ResqueJobsTree::Job
  class << self
    def perform_with_hook *args
      perform_without_hook *args
      after_perform_enqueue_parent *args
    end
    alias_method :perform_without_hook, :perform
    alias_method :perform, :perform_with_hook
  end
end
