module Tractor
  module Model
    class Base
      
      class << self
        attr_reader :redis
      end
      
      def self.redis
        @redis ||= Redis.new :db => 11
      end
      
      def initialize(attributes={})
        @attribute_store = {}
        attributes.each do |k,v|
          send("#{k}=", v)
        end
      end
      
      def save
        raise "Probably wanna set an id" if self.id.nil? || self.id.empty?
        
        scoped_attributes = attribute_store.inject({}) do |h, (key, value)| 
          h["#{self.class}:#{self.id}:#{key}"] = value
          h
        end
        Base.redis.mset scoped_attributes
        Base.redis.sadd "#{self.class}:all", self.id
      end
      
      def self.create(attributes={})
        m = new(attributes)
        m.save
      end
      
      def self.find(id)
        scoped_attributes = redis.mapped_mget(*redis.keys("#{self}:#{id}:*"))
        unscoped_attributes = scoped_attributes.inject({}) do |h, (key, value)| 
          h[key.split(":").last] = value
          h
        end
        self.new(unscoped_attributes)
      end
      
      class << self
        attr_reader :attributes
        
        def attribute(name, options=[])
          attributes[name] = Array(options).empty? ? name : options
          mapping, type = options
          setter(name, mapping, type)
          getter(name, mapping, type)
        end
        
        def all
          Base.redis.smembers("#{self}:all")
        end
        
        ###
        # Minions
        ###
        
        def setter(name, mapping, type)
          define_method(name) do
            value = @attribute_store[name]
            if type == :integer
              value.to_i
            elsif type == :boolean
              value.to_s.match(/(true|1)$/i) != nil
            else
              value
            end
          end
        end
        
        def getter(name, mapping, type)
          define_method(:"#{name}=") do |value|
            if type == :boolean
              value = value.to_s
            end
            @attribute_store[name] = value
          end
        end
        
        def attributes
          @attributes ||= {}
        end
      end
      
      private 
      
      attr_reader :attribute_store
    end
  end
end