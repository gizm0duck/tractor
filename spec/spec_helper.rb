$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'rubygems'
require 'tractor'
require 'spec'
require 'spec/autorun'
require 'redis'

Spec::Runner.configure do |config|
  config.before(:each) do 
    @redis = Tractor.connectdb
    Tractor.flushdb 
  end
end

class Callbackinator < Tractor::Model::Base
  attribute :id
  attribute :name
end

class Sammich < Tractor::Model::Base
  attribute :id
  attribute :product
  attribute :weight
  attribute :expensive, :type => :boolean
  index :product
  index :weight
end

class BananaClient < Tractor::Model::Mapper
  attribute :id
  attribute :name
end

class Banana
  attr_accessor :id, :type
  def initialize(id, type)
    @id = id; @type = type;
  end
end

class MonkeyClient < Tractor::Model::Mapper
  attribute :id
  attribute :birthday, :map => :birthdate
  attribute :evil, :type => :boolean, :map => :evil_monkey #[:evil_monkey, :boolean]
  index :evil
end

class Monkey
  attr_accessor :birthdate, :evil_monkey, :id
  
  def initialize(birthdate, evil_monkey, id)
    @id           = id
    @birthdate    = birthdate
    @evil_monkey  = evil_monkey
  end
end

class SlugClient < Tractor::Model::Mapper
  attribute :id
  attribute :banana_id
  
  depends_on BananaClient, :key_name => :banana_id, :method_name => :banana
end

class Slug
  attr_accessor :id, :banana_id
  
  def initialize(id, banana_id)
    @id = id; @banana_id = banana_id
  end
  
  def banana
    Banana.new(banana_id, "yellow")
  end
end
