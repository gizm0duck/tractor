require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Tractor::Model::Mapper do
  before do
    class Train < Tractor::Model::Mapper
      attribute :id
      attribute :name
      attribute :num_cars, :type => :integer, :map => :number_of_cars
      index :num_cars
    end
    
    class TrainServer
      attr_accessor :number_of_cars, :id

      def initialize(number_of_cars, id)
        @id             = id
        @number_of_cars = number_of_cars
      end
    end
    
    class SpecificTrain < TrainServer
      attr_accessor :name
      def initialize(name, number_of_cars, id)
        @id = id; @number_of_cars = number_of_cars; @name = name
      end
    end
  end
  
  describe ".value_mapper" do
    describe "when all of the mapped attributes are methods on the server object" do
      it "should include all attributes with their proper values" do
        train = SpecificTrain.new('Wabash Cannonball', 7, '5309')
        redis_train_attributes = Train.value_mapper(train)
        
        redis_train_attributes.keys.size.should == 3
        redis_train_attributes[:id].should == "5309"
        redis_train_attributes[:num_cars].should == 7
        redis_train_attributes[:name].should == "Wabash Cannonball"
      end
    end
    
    describe "when some of the mapped attributes do not exist on the server object" do
      it "should leave those mappings out of the attributes for the client object" do
        train = TrainServer.new(9, '5309')
        redis_train_attributes = Train.value_mapper(train)
        
        redis_train_attributes.keys.size.should == 3
        redis_train_attributes[:id].should == "5309"
        redis_train_attributes[:num_cars].should == 9
        redis_train_attributes[:name].should be_nil
      end
    end
  end
  
end