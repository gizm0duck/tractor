$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'rubygems'
require 'tractor'
require 'spec'
require 'spec/autorun'
require 'redis'

Spec::Runner.configure do |config|
  
end

class MonkeyClient < Tractor::Model::Base
  attribute :id
  attribute :birthday
  attribute :evil, [:evil_monkey, :boolean]
end

class Monkey
  attr_accessor :birthdate, :evil_monkey, :id
  
  def initialize(birthdate, evil_monkey, id)
    @id           = id
    @birthdate    = birthdate
    @evil_monkey  = evil_monkey
  end
end