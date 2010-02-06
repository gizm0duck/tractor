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
      
  #   describe ".dependencies_met?" do
  #     context "when all dependencies are met" do
  #       before do
  #         BananaClient.stub!(:dependency_met_for?).and_return(true)
  #       end
  #       
  #       it "returns true" do
  #         BananaClient.dependencies_met?(MonkeyClient).should be_true
  #       end
  #     end
  #     
  #     context "when any dependency is not met" do
  #       before do
  #         BananaClient.stub!(:dependency_met_for?).and_return(false)
  #       end
  #       
  #       it "returns false" do
  #         BananaClient.dependencies_met?(MonkeyClient).should be_false
  #       end
  #     end
  #   end
  
end