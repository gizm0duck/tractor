require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Tractor::Model::Base do
  attr_reader :redis
  before do
    module Tractor
      module Model
        class Player < Base
          attribute :id
          attribute :name
          attribute :wins_loses
          attribute :game_id
        end
    
        class Game < Tractor::Model::Base
          attribute :id
          attribute :board
          attribute :flying_object
          attribute :score, :type => :integer, :index => true
      
          association :players, Tractor::Model::Player
        end
      end
    end
  end
  
  after do
    Tractor.redis.flushdb
  end
  
  describe ".attribute" do
    it "inserts the values into the attributes class instance variable" do
      Tractor::Model::Game.attributes.should include(:board)
    end
    
    it "allows you to specify what type the value should be when it comes out of the tractor" do
      Tractor::Model::Game.attributes[:score][:type].should == :integer
    end
    
    it "creates a set method for each attribute" do
      game = Tractor::Model::Game.new(:board => "fancy")
      game.send(:attribute_store)[:board].should == "fancy"
    end
    
    it "creates a get method for each attribute" do
      game = Tractor::Model::Game.new(:board => "schmancy")
      game.board.should == "schmancy"
    end
    
    describe "when attribute is a boolean" do
      it "returns a boolean" do
        expensive_sammich = Sammich.new(:expensive => true)
        expensive_sammich.expensive.should == true
        expensive_sammich.expensive.should be_a(TrueClass)
      end
    end
    
    describe "when attribute is a integer" do
      it "returns an integer" do
        game = Tractor::Model::Game.new(:score => 1222)
        game.score.should == 1222
        game.score.should be_a(Fixnum)
      end
    end
    
    describe "when attribute is an index" do
      before do
        class Zombo < Tractor::Model::Base
          attribute :anything, :index => true
        end
      end
      
      it "returns creates an index for the attribute" do
        Zombo.indices.should == [:anything]
      end
    end
  end
    
  describe "#association" do
    attr_reader :game, :player1, :player2
    
    before do
      @game     = Tractor::Model::Game.new({ :id => 'g1' })
      Tractor::Model::Game.create({ :id => 'g2' })
      @player1  = Tractor::Model::Player.new({ :id => 'p1', :name => "delicious", :game_id => "g1" })
      @player2  = Tractor::Model::Player.new({ :id => 'p2', :name => "gross", :game_id => "g2" })
      
      game.save
      player1.save
      player2.save
    end
    
    it "adds a method with the given name to the instance" do # "Monkey:a1a:SET_NAME"
      game.players.should be_a(Tractor::Association)
    end
    
    it "adds a push method for the set on an instance of the class" do
      game.players.push player2
      redis.smembers('Tractor::Model::Game:g1:players').should == ['p1', 'p2']
    end
    
    it "adds an ids method for the set that returns all ids in it" do
      game.players.ids.should == [player1.id]
    end
    
    it "adds a count method for the set that returns the size of the association" do
      game.players.count.should == 1
    end
    
    it "automatically adds items to association when they are created" do
      bocci_ball = Tractor::Model::Game.create({ :id => "bocci_ball" })
      Tractor::Model::Player.create({ :id => "tobias", :name => "deciduous", :game_id => "bocci_ball" })
      bocci_ball.players.ids.should == ["tobias"]
    end
    
    it "adds an all method for the association to return the items in it" do
      player1_from_game = game.players.all[0]
      player1_from_game.name.should == player1.name
      player1_from_game.id.should == player1.id
    end
    
    it "requires the object being added to have been saved to the database before adding it to the association"
  end
  
  describe ".indices" do
    it "returns all indices on a class" do
      Sammich.indices.should == [:product, :weight]
    end
  end
  
  describe "index" do
    it "removes newline characters from index key"
  end
    
  describe ".attributes" do
    attr_reader :sorted_attributes
    
    before do
      @sorted_attributes = Tractor::Model::Game.attributes.keys.sort{|x,y| x.to_s <=> y.to_s}  
    end
  
    it "returns all attributes that have been added to this class" do
      sorted_attributes.size.should == 4
      sorted_attributes.should == [:board, :flying_object, :id, :score]
    end
    
    it "allows different attributes to be specified for different child classes" do
      Tractor::Model::Game.attributes.size.should == 4
      Tractor::Model::Player.attributes.size.should == 4
      
      Tractor::Model::Game.attributes.keys.should_not include(:name)
      Tractor::Model::Player.attributes.keys.should_not include(:flying_object)
    end
  end
  
  describe "#save" do
    it "raises if id is nil or empty" do
      game = Tractor::Model::Game.new
      game.id = nil
      lambda { game.save }.should raise_error(Tractor::MissingIdError, "Probably wanna set an id")
      game.id = ''
      lambda { game.save }.should raise_error(Tractor::MissingIdError, "Probably wanna set an id")
    end
    
    it "should write attributes to redis" do
      game = Tractor::Model::Game.new({:id => '1', :board => "large", :flying_object => "disc"})
      game.save
      
      redis_game_attributes = Tractor.redis.mapped_hmget("Tractor::Model::Game:1", "id", "board", "flying_object")
      redis_game_attributes["id"].should == "1"
      redis_game_attributes["board"].should == "large"
      redis_game_attributes["flying_object"].should == "disc"
    end
    
    it "appends the new object to the Game set" do
      Tractor::Model::Game.all.size.should == 0
      game = Tractor::Model::Game.new({ :id => '1', :board => "small" })
      game.save
      
      Tractor::Model::Game.all.size.should == 1
    end
    
    it "puts the record in the dirty set to be persisted to the databse the next time it polls" do
      Tractor::Model::Game.all.size.should == 0
      game = Tractor::Model::Game.new({ :id => '1', :board => "small" })
      game.save
      
      Tractor.redis.smembers("Tractor::Model::Dirty:all").should include("Tractor::Model::Game:1")
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
  
  describe ".ids" do
    before do
      Sammich.create({ :id => 's1', :weight => "medium", :product => "Turkey Avocado" })
      Sammich.create({ :id => 's2', :weight => "medium", :product => "Reuben Sammich" })
    end
    
    it "returns all the ids for a given class" do
      Sammich.ids.should == ['s1', 's2']
    end
  end
  
  describe ".count" do
    before do
      Sammich.create({ :id => 's1', :weight => "medium", :product => "Turkey Avocado" })
      Sammich.create({ :id => 's2', :weight => "medium", :product => "Reuben Sammich" })
    end
    
    it "returns the count of all items of a given class" do
      Sammich.count.should == 2
    end
  end
  
  describe "#create" do
    it "allows you to specify which attributes should be unique"

    it "raises exception if the id exists" do
      MonkeyClient.create({ :id => 'a1a', :evil => true, :birthday => "Dec 3" })
      lambda do
        MonkeyClient.create({ :id => 'a1a', :evil => false, :birthday => "Jan 4" })
      end.should raise_error(Tractor::DuplicateKeyError, "Duplicate value for MonkeyClient 'id'")
    end
    
    it "should write attributes to redis" do
      sammich = Sammich.create({ :id => '1', :product => "Veggie Sammich" })
      redis_sammich = Tractor.redis.mapped_hmget("Sammich:1", "id", "product")
      redis_sammich["id"].should == "1"
      redis_sammich["product"].should == "Veggie Sammich"
    end
    
    it "populates all the indices that are specified on the class" do
      Sammich.create({ :id => '1', :weight => "heavy", :product => "Ham Sammich" })
      Sammich.create({ :id => '2', :weight => "heavy", :product => "Tuna Sammich" })
  
      redis.smembers("Sammich:product:SGFtIFNhbW1pY2g=").should include('1')
      redis.smembers("Sammich:product:VHVuYSBTYW1taWNo").should include('2')
      redis.smembers("Sammich:weight:aGVhdnk=").should == ['1', '2']
    end
    
    it "returns the instance that has been created" do
      sammich = Sammich.create({ :id => '1', :weight => "heavy", :product => "Tuna Melt" })
      sammich.weight.should == "heavy"
    end
  end
  
  describe ".exists?" do
    it "returns true if the object with the given id exists" do
      MonkeyClient.create({ :id => 'a1a', :evil => true, :birthday => "Dec 3" })
      MonkeyClient.exists?('a1a').should be_true
    end
    
    it "returns false if the object with the given id does not exist" do
      MonkeyClient.exists?('a1a').should be_false
    end
  end
  
  describe ".find_by_id" do
    it "takes an id and returns the object from redis" do
      sammich = Sammich.create({ :id => '1', :product => "Cold Cut Trio" })
      
      redis_sammich = Sammich.find_by_id('1')
      redis_sammich.product.should == "Cold Cut Trio"
    end
    
    it "returns nil if the keys do not exist in redis" do
      Sammich.find_by_id('1').should be_nil
    end
  end
  
  describe "#update" do
    attr_reader :sammich
    
    before do
      @sammich = Sammich.create({ :id => '1', :weight => "medium", :product => "Turkey Avocado" })
    end
        
    it "updates the item from redis" do
      @sammich.update( {:weight => "heavy"} )
      @sammich.weight.should == "heavy"
    end
    
    it "does not update the id" do
      @sammich.update( {:id => "111111"} )
      @sammich.id.should == "1"
    end
    
    it "only changes attributes passed in" do
      @sammich.update( {:weight => "light"} )
      @sammich.id.should == "1"
      @sammich.weight.should == "light"
      @sammich.product.should == "Turkey Avocado"
    end
    
    it "updates all the indices associated with this object" do
      Sammich.find( {:weight => "light"} ).should be_empty
      Sammich.find( {:weight => "medium"} ).should_not be_empty
      sammich.update( {:weight => "light"} )
      Sammich.find( {:weight => "light"} ).should_not be_empty
      Sammich.find( {:weight => "medium"} ).should be_empty
    end
    
    it "raises if object has not been saved yet"
  end
  
  describe "#destroy" do
    attr_reader :cheese, :balogna
    
    before do
      @cheese = Sammich.create({ :id => '1', :weight => "medium", :product => "Cheese Sammich" })
      @balogna = Sammich.create({ :id => '2', :weight => "medium", :product => "Balogna Sammich" })
    end
    
    it "removes the item from redis" do
      @cheese.destroy
      Sammich.find_by_id(cheese.id).should be_nil
    end
    
    it "removes the id from the all index" do
      Sammich.all.map{|t| t.id }.should == ["1", "2"]
      cheese.destroy
      Sammich.all.map{|t| t.id }.should == ["2"]
    end
    
    it "removes the id from all of it's other indices" do
      Sammich.find({ :weight => "medium" }).size.should == 2
      cheese.destroy
      Sammich.find({ :weight => "medium" }).size.should == 1
    end
    
    it "removes the id from all of the associations that it may be in" do
      bocci_ball = Tractor::Model::Game.create({ :id => "bocci_ball" })
      tobias = Tractor::Model::Player.create({ :id => "tobias", :name => "deciduous", :game_id => "bocci_ball" })
      bocci_ball.players.ids.should == ["tobias"]
      tobias.destroy
      
      bocci_ball.players.ids.should == []
    end
  end
  
  describe ".find" do
    attr_reader :cheese, :balogna
    
    before do
      @cheese   = Sammich.create({ :id => '1', :weight => "medium", :product => "Cheese Sammich" })
      @balogna  = Sammich.create({ :id => '2', :weight => "medium", :product => "Balogna Sammich" })
      @meat   = Sammich.create({ :id => '3', :weight => "heavy", :product => "Meat & More Sammich" })
    end
    
    context "when searching on 1 attribute" do
      it "returns all matching products" do
        redis_cheese, redis_balogna = Sammich.find( {:weight => "medium" } )
        
        redis_cheese.id.should == cheese.id
        redis_cheese.product.should == cheese.product
        redis_balogna.id.should == balogna.id
        redis_balogna.product.should == balogna.product
      end
    end
    
    context "when searching on multiple attribute" do
      it "returns the intersection of all matching objects" do
        sammiches = Sammich.find( {:weight => "medium", :product => "Cheese Sammich" } )
        sammiches.size.should == 1
        sammiches[0].id.should == "1"
        sammiches[0].product.should == "Cheese Sammich"
      end
    end
    
    it "returns empty array if no options are given" do
      Sammich.find({}).should == []
    end
    
    it "returns empty array if nothing matches the given options" do
      Sammich.find( {:weight => "light" } ).should == []
    end
    
    it "returns all matching objects if multiple values are given for an attribute" do
      Sammich.find( {:weight => ["medium", "heavy"]} ).map(&:id).sort.should == ['1','2','3']
    end
  end
  
  describe ".find_by_attribute" do
    it "raises if index does not exist for given key" do
      lambda do
        Sammich.find_by_attribute(:expensive, true)
      end.should raise_error(Tractor::MissingIndexError, "No index on 'expensive'")
    end
    
    it "takes an index name and value and finds all matching objects" do
      meat_supreme = Sammich.create({ :id => '1', :weight => "heavy", :product => "Meat Supreme" })
      bacon_with_bacon = Sammich.create({ :id => '2', :weight => "heavy", :product => "Bacon with extra Bacon" })
    
      redis_meat_supreme, redis_bacon_with_bacon = Sammich.find_by_attribute(:weight, "heavy")
      redis_meat_supreme.id.should == meat_supreme.id
      redis_meat_supreme.weight.should == meat_supreme.weight
      redis_meat_supreme.product.should == meat_supreme.product
      
      redis_bacon_with_bacon.id.should == bacon_with_bacon.id
      redis_bacon_with_bacon.weight.should == bacon_with_bacon.weight
      redis_bacon_with_bacon.product.should == bacon_with_bacon.product
    end
    
    it "returns nil if nothing matches" do
      Sammich.find_by_attribute(:weight, "heavy").should == []
    end
  end
  
  describe ".to_h" do
    it "returns the attributes for a mapped object in a hash" do
      chicken = Sammich.create({ :id => '1', :weight => "heavy", :product => "Chicken" })
      
      chicken = Sammich.find_by_id('1')
      hashed_attributes = chicken.to_h
      hashed_attributes[:id].should == "1"
      hashed_attributes[:weight].should == "heavy"
      hashed_attributes[:product].should == "Chicken"
    end
  end
end
