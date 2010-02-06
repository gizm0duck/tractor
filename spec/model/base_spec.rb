require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Tractor::Model::Base do
  attr_reader :redis
  before do
    class Game < Tractor::Model::Base
      attribute :id
      attribute :board
      attribute :flying_object
      attribute :score, :type => :integer
    end
    
    class Player < Tractor::Model::Base
      attribute :id
      attribute :name
      attribute :wins_loses
    end
    
    class JohnDeere < Tractor::Model::Base
      attribute :id
      attribute :product
      attribute :weight
      attribute :expensive, :type => :boolean
      index :product
      index :weight
    end
    
    @redis = Redis.new :db => 11
  end
  
  describe ".attribute" do
    it "inserts the values into the attributes class instance variable" do
      Game.attributes.should include(:board)
    end
    
    it "allows you to specify what type the value should be when it comes out of the tractor" do
      Game.attributes[:score][:type].should == :integer
    end
    
    it "creates a set method for each attribute" do
      game = Game.new(:board => "fancy")
      game.send(:attribute_store)[:board].should == "fancy"
    end
    
    it "creates a get method for each attribute" do
      game = Game.new(:board => "schmancy")
      game.board.should == "schmancy"
    end
    
    describe "when attribute is a boolean" do
      it "returns a boolean" do
        tractor = JohnDeere.new(:expensive => true)
        tractor.expensive.should == true
        tractor.expensive.should be_a(TrueClass)
      end
    end
    
    describe "when attribute is a integer" do
      it "returns an integer" do
        game = Game.new(:score => 1222)
        game.score.should == 1222
        game.score.should be_a(Fixnum)
      end
    end
  end
  
  describe "#association" do
    attr_reader :monkey, :banana, :banana2
    
    before do
      @monkey   = MonkeyClient.new({ :id => 'a1a', :evil => true, :birthday => "Dec 3" })
      @banana   = BananaClient.new({ :id => 'b1b', :name => "delicious" })
      @banana2  = BananaClient.new({ :id => 'b2b', :name => "gross" })
      
      monkey.save
      banana.save
    end
    
    it "adds a set with the given name to the instance" do # "Monkey:a1a:SET_NAME"
      MonkeyClient.associations.keys.should include(:bananas)
    end
    
    it "adds a push method for the set on an instance of the class" do
      monkey.bananas.push banana
      redis.smembers('MonkeyClient:a1a:bananas').should == ['b1b']
    end
    
    it "adds an all method for the association to return the items in it" do
      banana2.save
      monkey.bananas.all.should == []
      monkey.bananas.push banana
      monkey.bananas.push banana2
      banana_from_monkey  = monkey.bananas.all[0]
      banana2_from_monkey = monkey.bananas.all[1]
      
      banana_from_monkey.name.should == banana.name
      banana_from_monkey.id.should == banana.id
      banana2_from_monkey.name.should == banana2.name
      banana2_from_monkey.id.should == banana2.id
    end
    
    it "requires the object being added to have been saved to the database before adding it to the set"
  end
  
  describe ".associations" do
    it "returns all association that have been added to this class" do
      MonkeyClient.associations.keys.should == [:bananas]
    end
  end
  
  describe ".indices" do
    it "returns all indices on a class" do
      JohnDeere.indices.should == [:product, :weight]
    end
  end
  
  describe "index" do
    it "removes newline characters from index key"
  end
    
  describe ".attributes" do
    attr_reader :sorted_attributes
    
    before do
      @sorted_attributes = Game.attributes.keys.sort{|x,y| x.to_s <=> y.to_s}  
    end
  
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
    it "allows you to specify which attributes should be unique"
    it "raises exception if the id exists" do
      MonkeyClient.create({ :id => 'a1a', :evil => true, :birthday => "Dec 3" })
      lambda do
        MonkeyClient.create({ :id => 'a1a', :evil => false, :birthday => "Jan 4" })
      end.should raise_error("Duplicate value for MonkeyClient 'id'")
    end
    
    it "should write attributes to redis" do
      monkey = MonkeyClient.create({ :id => 'a1a', :evil => true, :birthday => "Dec 3" })
      
      redis["MonkeyClient:a1a:id"].should == "a1a"
      redis["MonkeyClient:a1a:evil"].should == "true"
      redis["MonkeyClient:a1a:birthday"].should == "Dec 3"
    end
    
    it "populates all the indices that are specified on the class" do
      JohnDeere.create({ :id => 'a1a', :weight => "heavy", :product => "harvester" })
      JohnDeere.create({ :id => 'b2b', :weight => "heavy", :product => "seeder" })
  
      redis.smembers("JohnDeere:product:aGFydmVzdGVy").should include('a1a')
      redis.smembers("JohnDeere:product:c2VlZGVy").should include('b2b')
      redis.smembers("JohnDeere:weight:aGVhdnk=").should == ['a1a', 'b2b']
    end
    
    it "returns the instance that has been created" do
      harvester = JohnDeere.create({ :id => 'a1a', :weight => "heavy", :product => "harvester" })
      harvester.weight.should == "heavy"
    end
  end
  
  describe ".find_by_id" do
    it "takes an id and returns the object from redis" do
      monkey = MonkeyClient.create({ :id => 'a1a', :evil => true, :birthday => "Dec 3" })
      
      redis_monkey = MonkeyClient.find_by_id('a1a')
      redis_monkey.birthday.should == "Dec 3"
    end
    
    it "returns nil if the keys do not exist in redis" do
      MonkeyClient.find_by_id('a1a').should be_nil
    end
  end
  
  describe "#update" do
    it "should be specced"
  end
  
  describe "#destroy" do
    it "should be specced"
  end
  
  describe ".find" do
    attr_reader :harvester, :seeder
    before do
      @harvester = JohnDeere.create({ :id => 'a1a', :weight => "heavy", :product => "harvester" })
      @seeder = JohnDeere.create({ :id => 'b2b', :weight => "heavy", :product => "seeder" })
    end
    
    context "when searching on 1 attribute" do
      it "returns all matching products" do
        redis_harvester, redis_seeder = JohnDeere.find( {:weight => "heavy" } )
        
        redis_harvester.id.should == harvester.id
        redis_harvester.product.should == harvester.product
        redis_seeder.id.should == seeder.id
        redis_seeder.product.should == seeder.product
      end
    end
    
    context "when searching on multiple attribute" do
      it "returns the intersection of all matching objects" do
        products = JohnDeere.find( {:weight => "heavy", :product => "seeder" } )
        products.size.should == 1
        products[0].id.should == "b2b"
        products[0].product.should == "seeder"
      end
    end
    
    it "returns empty array if no options are given" do
      JohnDeere.find({}).should == []
    end
    
    it "returns empty array if nothing matches the given options" do
      JohnDeere.find( {:weight => "light" } ).should == []
    end
  end
  
  describe ".find_by_attribute" do
    it "raises if index does not exist for given key" do
      lambda do
        JohnDeere.find_by_attribute(:expensive, true)
      end.should raise_error("No index on 'expensive'")
    end
    
    it "takes an index name and value and finds all matching objects" do
      harvester = JohnDeere.new({ :id => 'a1a', :weight => "heavy", :product => "harvester" })
      seeder = JohnDeere.new({ :id => 'b2b', :weight => "heavy", :product => "seeder" })
      harvester.save
      seeder.save
    
      redis_harvester, redis_seeder = JohnDeere.find_by_attribute(:weight, "heavy")
      redis_harvester.id.should == harvester.id
      redis_harvester.weight.should == harvester.weight
      redis_harvester.product.should == harvester.product
      
      redis_seeder.id.should == seeder.id
      redis_seeder.weight.should == seeder.weight
      redis_seeder.product.should == seeder.product
    end
    
    it "returns nil if nothing matches" do
      JohnDeere.find_by_attribute(:weight, "heavy").should == []
    end
  end
  
  describe ".to_h" do
    it "returns the attributes for a mapped object in a hash" do
      harvester = JohnDeere.create({ :id => 'a1a', :weight => "heavy", :product => "harvester" })
      
      harvester = JohnDeere.find_by_id('a1a')
      hashed_attributes = harvester.to_h
      hashed_attributes[:id].should == "a1a"
      hashed_attributes[:weight].should == "heavy"
      hashed_attributes[:product].should == "harvester"
    end
  end
end
