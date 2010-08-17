require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Tractor::Model::Mapper do
  before do
    class RedisTrain < Tractor::Model::Mapper
      attribute :id
      attribute :name
      attribute :num_cars, :type => :integer, :map => :number_of_cars
      index :num_cars
    end
    
    class Train
      attr_accessor :number_of_cars, :id

      def initialize(number_of_cars, id)
        @id             = id
        @number_of_cars = number_of_cars
      end
    end
    
    class FamousTrain < Train
      attr_accessor :name
      def initialize(name, number_of_cars, id)
        @id = id; @number_of_cars = number_of_cars; @name = name
      end
    end
  end
  
  describe ".attribute_mapper" do
    describe "when all of the mapped attributes are methods on the server object" do
      it "should include all attributes with their proper values" do
        train = FamousTrain.new('Wabash Cannonball', 7, '5309')
        redis_train_attributes = RedisTrain.attribute_mapper(train)
        
        redis_train_attributes.keys.size.should == 3
        redis_train_attributes[:id].should == "5309"
        redis_train_attributes[:num_cars].should == 7
        redis_train_attributes[:name].should == "Wabash Cannonball"
      end
    end
    
    describe "when some of the mapped attributes do not exist on the server object" do
      it "should leave those mappings out of the attributes for the client object" do
        train = Train.new(9, '5309')
        redis_train_attributes = RedisTrain.attribute_mapper(train)
        
        redis_train_attributes.keys.size.should == 3
        redis_train_attributes[:id].should == "5309"
        redis_train_attributes[:num_cars].should == 9
        redis_train_attributes[:name].should be_nil
      end
    end
  end
  
  describe "find_from_instance" do
    it "returns nil if record does not exist in redis" do
      monkey_1 = Monkey.new("Dec. 3, 1981", true, 'a1a')
      monkey_client_1 = MonkeyClient.find_from_instance(monkey_1)
      monkey_client_1.should be_nil
    end
    
    it "returns the object from redis if it exists" do      
      monkey_1 = Monkey.new("Dec. 3, 1981", true, 'a1a')
      monkey_2 = Monkey.new("Dec. 4, 1981", false, 'b1b')
      
      MonkeyClient.create_from_instance(monkey_1)
      MonkeyClient.create_from_instance(monkey_2)
      MonkeyClient.all.size.should == 2
      
      redis_monkey_1 = MonkeyClient.find_from_instance(monkey_1)
      redis_monkey_2 = MonkeyClient.find_from_instance(monkey_2)
      
      redis_monkey_1.birthday.should == "Dec. 3, 1981"
      redis_monkey_2.birthday.should == "Dec. 4, 1981"
      
      redis_monkey_1.evil.should == true
      redis_monkey_2.evil.should == false
    end
  end
  
  describe "create_from_instance" do
    it "ensures dependencies are met"
    it "writes the client representation out to redis with proper object types" do
      monkey = Monkey.new("Dec. 3, 1981", true, 'a1a')
      redis_monkey = MonkeyClient.create_from_instance(monkey)
      
      redis_monkey = MonkeyClient.all.first
      redis_monkey.birthday.should == "Dec. 3, 1981"
      redis_monkey.evil.should == true
      redis_monkey.id.should == "a1a"
    end
    
    context "when the instance already exists in it's tractor representation" do
      attr_reader :monkey, :tractor_monkey
      before do
        @monkey = Monkey.new("Dec. 3, 1981", true, 'a1a')
        @tractor_monkey = MonkeyClient.create_from_instance(monkey)
      end
      
      it "returns the instance from the tractor representation" do
        result = MonkeyClient.create_from_instance(monkey)
        result.id.should        == tractor_monkey.id
        result.birthday.should  == tractor_monkey.birthday
        result.evil.should      == tractor_monkey.evil
      end
    end
  end
  
  
  describe "update_from_instance" do
    it "ensures dependencies are met"
    it "finds an existing record based on id and updates the attributes accordingly" do
      monkey = Monkey.new("Dec. 3, 1981", true, 'a1a')
      redis_monkey = MonkeyClient.create_from_instance(monkey)
      
      MonkeyClient.all.size.should == 1
      redis_monkey = MonkeyClient.all.first
      redis_id = redis_monkey.id
      redis_monkey.id.should == monkey.id
      
      monkey.birthdate = "Dec. 2, 1981"
      monkey.evil_monkey = false
      
      MonkeyClient.update_from_instance(monkey)
      MonkeyClient.all.size.should == 1
      redis_monkey = MonkeyClient.find_by_id(redis_id)
      
      redis_monkey.birthday.should == "Dec. 2, 1981"
      redis_monkey.evil.should == false
    end
    
    it "raises if record does not exist" do
      MonkeyClient.all.should be_empty
      monkey = Monkey.new("Dec. 3, 1981", true, 'a1a')
      
      lambda do 
        redis_monkey = MonkeyClient.update_from_instance(monkey)
      end.should raise_error("Cannot update an object that doesn't exist.")
    end
  end
  
  describe ".remove" do
    it "removes the client representation with the given id" do
      monkey = Monkey.new("Dec. 3, 1981", true, 'a1a')
      redis_monkey = MonkeyClient.create_from_instance(monkey)
      
      MonkeyClient.find_from_instance(monkey).should_not be_nil
      MonkeyClient.remove(monkey.id)
      MonkeyClient.find_from_instance(monkey).should be_nil
    end
    
    it "returns false if the client representation with the given id does not exist" do
      monkey = Monkey.new("Dec. 3, 1981", true, 'a1a')
      
      MonkeyClient.remove(monkey.id).should be_false
      MonkeyClient.find_from_instance(monkey).should be_nil
    end
  end
  
  describe ".representation_for" do
    attr_reader :monkey
    
    before do
      @monkey = Monkey.new("Dec. 3, 1981", true, 'aabc1')
    end
    
    context "when the object does NOT exist in the cache" do
      before do
        MonkeyClient.all.should be_empty
      end
      
      it "inserts the object and returns it" do
        monkey_client = MonkeyClient.representation_for(monkey)
        monkey_client.class.should == MonkeyClient
        monkey_client.birthday.should == "Dec. 3, 1981"
        monkey_client.evil.should == true
      end
    end
    
    context "when the object exists in the cache" do
      before do
        monkey_client = MonkeyClient.create_from_instance(monkey)
        MonkeyClient.find_by_id(monkey.id).should_not be_nil
        monkey_client.birthday.should == monkey.birthdate
        MonkeyClient.all.size.should == 1
      end
      
      it "updates the values and returns the object" do
        monkey.birthdate = "Nov. 27, 1942"
        monkey_client = MonkeyClient.representation_for(monkey)
        monkey_client.birthday.should == "Nov. 27, 1942"
        MonkeyClient.all.size.should == 1
      end
    end
  end
  
  describe "dependencies" do
    it "returns a list of all the dependencies for this class" do
      dependencies = SlugClient.dependencies
      dependencies.keys.should == [BananaClient]
      dependencies[BananaClient][:key_name].should == :banana_id
      dependencies[BananaClient][:method_name].should == :banana
    end
  end
  
  describe ".dependency_met_for?" do
    attr_reader :slug
    before do
      @slug = Slug.new('slug_1', "banana_1")
    end
    
    context "when dependency is met" do
      before do
        banana = BananaClient.create_from_instance(Banana.new("banana_1", "yellow"))
        BananaClient.find_by_id(banana.id).should_not be_nil
      end
      
      it "returns true" do
        SlugClient.dependency_met_for?(slug, BananaClient).should be_true
      end
    end
    
    context "when dependency is NOT met" do
      before do
        MonkeyClient.find_by_id(slug.banana_id).should be_nil
      end
      
      it "returns false" do
        SlugClient.dependency_met_for?(slug, BananaClient).should be_false
      end
    end
  end
      
  describe ".dependencies_met?" do
    context "when all dependencies are met" do
      before do
        SlugClient.stub!(:dependency_met_for?).and_return(true)
      end
      
      it "returns true" do
        SlugClient.dependencies_met?(BananaClient).should be_true
      end
    end
    
    context "when any dependency is not met" do
      before do
        SlugClient.stub!(:dependency_met_for?).and_return(false)
      end
      
      it "returns false" do
        SlugClient.dependencies_met?(BananaClient).should be_false
      end
    end
  end
  
  describe ".ensure_dependencies_met" do
    attr_reader :banana, :slug
    describe "when the dependencies are met" do
      before do
        SlugClient.stub!(:dependencies_met?).and_return(true)
        @banana = Banana.new('banana1', 'yellowish')
        @slug = Slug.new('slug1', 'banana1')
      end
      
      it "Does not create any objects" do
        BananaClient.all.should be_empty
        SlugClient.ensure_dependencies_met(banana)
        BananaClient.all.should be_empty
      end
    end
    
    describe "when the dependencies are NOT met" do
      before do
        @banana = Banana.new('banana1', 'yellowish')
        @slug = Slug.new('slug1', 'banana1')
        
        SlugClient.dependencies_met?(slug).should be_false
      end
      
      it "creates the dependent objects" do
        BananaClient.all.should be_empty
        SlugClient.ensure_dependencies_met(slug)
        BananaClient.all.should_not be_empty
      end
    end
  end
end