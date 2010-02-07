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
  
  class Index
    include Enumerable
    attr_reader :klass, :name, :value
    
    def initialize(klass, name, value)
      @klass = klass
      @name = name
      @value = value
    end
    
    def insert(id)
      Tractor.redis.sadd(key, id) unless Tractor.redis.smembers(key).include?(id)
    end
    
    def delete(id)
      Tractor.redis.srem(key, id)
    end
    
    def self.key_for(klass, name, value)
      i = self.new(klass, name, value)
      i.key
    end
    
    def key
      encoded_value = "#{Base64.encode64(value.to_s)}".gsub("\n", "")
      "#{klass}:#{name}:#{encoded_value}"
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
        key_base = "#{self.class}:#{self.id}"
        #raise "Duplicate value for #{self.class} 'id'" if Tractor.redis.keys("#{key_base}:*").any?
        
        scoped_attributes = attribute_store.inject({}) do |h, (attr_name, value)| 
          h["#{key_base}:#{attr_name}"] = value
          h
        end
        Tractor.redis.mset scoped_attributes
        Tractor.redis.sadd "#{self.class}:all", self.id
        add_to_indices
        
        return self
      end
      
      def destroy
        key_base = "#{self.class}:#{self.id}"
        keys = Tractor.redis.keys("#{key_base}:*")

        keys.map{|k| k.split(":").last }.each do |name|
          if self.class.indices.include?(name.to_sym)
            index = Index.new(self.class, name, self.send(name))
            index.delete(self.id)
          end
        end
        Tractor.redis.srem("#{self.class}:all", self.id)
        keys.each { |k| Tractor.redis.del k }
      end
      
      def update(attributes = {})
        attributes.delete(:id)
        
        attributes.each do |name, value|
          if self.class.indices.include?(name.to_sym)
            index = Index.new(self.class, name, self.send(name))
            index.delete(self.id)
          end
        end
        
        attributes.each{ |k,v| self.send("#{k}=", v) }
        save
      end
      
      def add_to_indices
        self.class.indices.each do |name|
          index = Index.new(self.class, name, send(name))
          index.insert(self.id)
        end
      end
      
      def to_h
        attribute_store
      end
      
      def self.create(attributes={})
        m = new(attributes)
        m.save
        m
      end
      
      def self.find_by_id(id)
        keys = Tractor.redis.keys("#{self}:#{id}:*")
        return nil if keys.empty?
        
        scoped_attributes = Tractor.redis.mapped_mget(*keys)
        unscoped_attributes = scoped_attributes.inject({}) do |h, (key, value)| 
          h[key.split(":").last] = value
          h
        end
        self.new(unscoped_attributes)
      end
      
      # use method missing to do craziness, or define a find_by on each index (BETTER)
      def self.find_by_attribute(name, value)
        raise "No index on '#{name}'" unless indices.include?(name)
        
        ids = Tractor.redis.smembers(Index.key_for(self, name, value))
        ids.map do |id|
          find_by_id(id)
        end
      end
      
      def self.find(options = {})
        return [] if options.empty?
        sets = options.map do |name, value|
          Index.key_for(self, name, value)
        end
        ids = Tractor.redis.sinter(*sets)
        ids.map do |id|
          find_by_id(id)
        end
      end
      
      class << self
        attr_reader :attributes, :associations, :indices
        
        def attribute(name, options={})
          options[:map] = name unless options[:map]
          attributes[name] = options
          setter(name, options[:type])
          getter(name, options[:type])
        end
        
        def index(name)
          indices << name unless indices.include?(name)
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
        
        def getter(name, type)
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
        
        def setter(name, type)
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