require 'base64'

module Tractor
  
  class << self
    attr_reader :redis
  end
  
  def self.redis
    @redis ||= Redis.new :db => 11
  end
  
  class Set
    include Enumerable
    
    attr_accessor :key, :klass

    def initialize(key, klass)
      self.klass = klass
      self.key = key
    end
    
    def push(val)
      Tractor.redis.sadd key, val.id
    end
    
    def all
      ids = Tractor.redis.smembers(key)
      ids.inject([]){ |a, id| a << klass.find_by_id(id); a }
    end
    
  end
  
  module Model
    class Base
      def initialize(attributes={})
        @attribute_store = {}
        @association_store = {}
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
        Tractor.redis.mset scoped_attributes
        Tractor.redis.sadd "#{self.class}:all", self.id
        update_indices
      end
      
      def update_indices
        self.class.indices.each do |name|
          encoded_value = "#{Base64.encode64(self.send(name).to_s)}".gsub("\n", "")
          Tractor.redis.sadd "#{self.class}:#{name}:#{encoded_value}", self.id
        end
      end
      
      def self.create(attributes={})
        m = new(attributes)
        m.save
        m
      end
      
      def self.find_by_id(id)
        scoped_attributes = Tractor.redis.mapped_mget(*Tractor.redis.keys("#{self}:#{id}:*"))
        unscoped_attributes = scoped_attributes.inject({}) do |h, (key, value)| 
          h[key.split(":").last] = value
          h
        end
        self.new(unscoped_attributes)
      end
      
      def self.find(name, value)
        encoded_value = "#{Base64.encode64(value).to_s}".gsub("\n", "")
        ids = Tractor.redis.smembers("#{self}:#{name}:#{encoded_value}")
        ids.map do |id|
          find_by_id(id)
        end
      end
      
      class << self
        attr_reader :attributes, :associations, :indices
        
        def attribute(name, options=[])
          attributes[name] = Array(options).empty? ? name : options
          mapping, type = options
          setter(name, mapping, type)
          getter(name, mapping, type)
        end
        
        def index(name)
          indices << name
        end
        
        def association(name, klass)
          associations[name] = name
          
          define_method(name) do
            @association_store[name] = Set.new("#{self.class}:#{self.id}:#{name}", klass)
          end
        end
        
        def all
          ids = Tractor.redis.smembers("#{self}:all")
          ids.inject([]){ |a, id| a << find_by_id(id); a }
        end
        
        ###
        # Minions
        ###
        
        def getter(name, mapping, type)
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
        
        def setter(name, mapping, type)
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
        
        def associations
          @associations ||= {}
        end
        
        def indices
          @indices ||= []
        end
      end
      
      private 
      
      attr_reader :attribute_store, :association_store
    end
  end
end