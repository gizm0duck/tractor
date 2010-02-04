require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Tractor::Model::Base do
  attr_reader :redis
  before do
    class Game < Tractor::Model::Base
      attribute :id
      attribute :board
      attribute :flying_object, :beanbag
      attribute :score, [:points, :integer]
    end
    
    class Player < Tractor::Model::Base
      attribute :id
      attribute :name
      attribute :wins_loses, :record
    end
    
    @redis = Redis.new :db => 11
  end
  
  describe ".attribute" do
    it "inserts the values into the attributes class instance variable" do
      Game.attributes.should include(:board)
    end
    
    it "allows you to specify the mapping for the tractor representation to another object" do
      Game.attributes[:flying_object].should == :beanbag
    end
    
    it "defaults the mapping to the attribute name if none is given" do
      Game.attributes[:board].should == :board
    end
    
    it "allows you to specify what type the value should be when it comes out of the tractor" do
      Game.attributes[:score].should == [:points, :integer]
    end
    
    it "creates a set method for each attribute" do
      game = Game.new
      game.board = "fancy"
      game.send(:attribute_store)[:board].should == "fancy"
    end
    
    
    it "creates a get method for each attribute" do
      game = Game.new
      game.board = "schmancy"
      game.board.should == "schmancy"
    end
    
    describe "when attribute is a boolean" do
      
    end
    
    describe "when attribute is a integer" do
      
    end
  end
  
  describe "#set" do
    attr_reader :monkey, :banana
    
    before do
      @monkey = MonkeyClient.new({ :id => 'a1a', :evil => true, :birthday => "Dec 3" })
      @banana = BananaClient.new({ :id => 'b1b', :name => "delicious" })
      
      monkey.save
      banana.save
    end
    
    it "adds a set with the given name to the instance" do # "Monkey:a1a:SET_NAME"
      MonkeyClient.sets.keys.should include(:bananas)
    end
    
    it "adds a push method for the set on an instance of the class" do
      monkey.bananas.push banana
      redis.smembers('MonkeyClient:a1a:bananas').should == ['b1b']
    end
    
    it "adds an all method for the set to return the items in it" do
      monkey.bananas.all.should == []
      monkey.bananas.push banana
      banana_from_monkey = monkey.bananas.all[0]
      
      banana_from_monkey.name.should == banana.name
      banana_from_monkey.id.should == banana.id
    end
  end
  
  describe ".sets" do
    it "returns all sets that have been added to this class" do
      MonkeyClient.sets.keys.should == [:bananas]
    end
  end
  
  describe ".attributes" do
    attr_reader :sorted_attributes
    
    before do
      @sorted_attributes = Game.attributes.keys.sort{|x,y| x.to_s <=> y.to_s}  
    end
    
    it "has a default attribute of id"
  
    it "returns all attributes that have been added to this class" do
      sorted_attributes.size.should == 4
      sorted_attributes.should == [:board, :flying_object, :id, :score]
    end
    
    it "allows different attributes to be specified for different child classes" do
      Game.attributes.size.should == 4
      Player.attributes.size.should == 3
      
      Game.attributes.keys.should_not include(:name)
      Player.attributes.keys.should_not include(:flying_object)
    end
  end
  
  describe "#save" do
    it "raises if id is nil or empty" do
      monkey = MonkeyClient.new
      monkey.id = nil
      lambda { monkey.save }.should raise_error("Probably wanna set an id")
      monkey.id = ''
      lambda { monkey.save }.should raise_error("Probably wanna set an id")
    end
    
    it "should write attributes to redis" do
      monkey = MonkeyClient.new
      monkey.id = 'a1a'
      monkey.evil = true
      monkey.birthday = "Dec 3"
      monkey.save
      
      redis["MonkeyClient:a1a:id"].should == "a1a"
      redis["MonkeyClient:a1a:evil"].should == "true"
      redis["MonkeyClient:a1a:birthday"].should == "Dec 3"
    end
    
    it "appends the new object to the MonkeyClient set" do
      MonkeyClient.all.size.should == 0
      monkey = MonkeyClient.new({ :id => 'a1a', :evil => true, :birthday => "Dec 3" })
      monkey.save
      
      MonkeyClient.all.size.should == 1
    end
  end
  
  describe ".all" do
    it "every object that is created for this class will be in this set" do
      MonkeyClient.all.size.should == 0
      MonkeyClient.create({ :id => 'a1a', :evil => true, :birthday => "Dec 3" })
      MonkeyClient.create({ :id => 'b1b', :evil => false, :birthday => "Dec 4" })
      MonkeyClient.all.size.should == 2
    end
    
    it "each class only tracks their own" do
      MonkeyClient.all.size.should == 0
      BananaClient.all.size.should == 0
      
      MonkeyClient.create({ :id => 'a1a', :evil => true, :birthday => "Dec 3" })
      BananaClient.create({ :id => 'a1a', :name => "delicious" })
      
      MonkeyClient.all.size.should == 1
      BananaClient.all.size.should == 1
    end
    
    it "returns the entire instance of a given object" do
      MonkeyClient.create({ :id => 'a1a', :evil => true, :birthday => "Dec 3" })
      MonkeyClient.all[0].birthday.should == "Dec 3"
    end
  end
  
  describe "#create" do
    it "fails if the id exists"
    it "should write attributes to redis" do
      monkey = MonkeyClient.create({ :id => 'a1a', :evil => true, :birthday => "Dec 3" })
      
      redis["MonkeyClient:a1a:id"].should == "a1a"
      redis["MonkeyClient:a1a:evil"].should == "true"
      redis["MonkeyClient:a1a:birthday"].should == "Dec 3"
    end
    
    it "returns the instance that has been created"
  end
  
  describe "#find" do
    it "takes an id and returns the object from redis" do
      monkey = MonkeyClient.create({ :id => 'a1a', :evil => true, :birthday => "Dec 3" })
      
      redis_monkey = MonkeyClient.find('a1a')
      redis_monkey.birthday.should == "Dec 3"
    end
  end
end
