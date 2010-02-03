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
  end
end
