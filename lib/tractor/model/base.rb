require 'base64'
require 'yajl'

module Tractor
  
  class MissingIdError < StandardError; end
  class DuplicateKeyError < StandardError; end
  class MissingIndexError < StandardError; end
  
  class << self
    attr_reader :redis
    
    # important options are port, host and db
    def connectdb(options={})
      @redis = options.nil? ? Redis.new(:db => 1) : Redis.new(options)
    end

    def flushdb
      @redis.flushdb
    end
  end
  
  class Association
    attr_accessor :key, :klass

    def initialize(key, klass)
      self.klass = klass
      self.key = key
    end
    
    def push(val)
      Tractor.redis.sadd(key, val.id)
    end
    
    def delete(id)
      Tractor.redis.srem(key, id)
    end
    
    def ids
      Tractor.redis.smembers(key) || []
    end
    
    def all
      ids.inject([]){|o, id| o << klass.find_by_id(id); o }
    end
  end
  
  class Index
    attr_reader :klass, :name, :value
    
    def initialize(klass, name, value)
      @klass = klass
      @name = name
      @value = value
    end
    
    def insert(id)
      Tractor.redis.sadd(key, id) unless Tractor.redis.sismember(key, id)
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
        @encoder = Yajl::Encoder.new
        attributes.each do |k,v|
          send("#{k}=", v)
        end
      end
      
      def save
        raise MissingIdError, "Probably wanna set an id" if self.id.nil? || self.id.to_s.empty?
        Tractor.redis["#{self.class}:#{self.id}"] = @encoder.encode(self.send(:attribute_store))
        Tractor.redis.sadd "#{self.class}:all", self.id
        add_to_indices
        add_to_associations
        
        return self
      end
      
      def destroy
        delete_from_indices(attribute_store)
        remove_from_associations
        Tractor.redis.srem("#{self.class}:all", self.id)
        Tractor.redis.del "#{self.class}:#{self.id}"
      end
      
      def update(attributes = {})
        attributes.delete(:id)
        delete_from_indices(attributes)
        attributes.each{|k,v| self.send("#{k}=", v) }
        save
      end
      
      def add_to_associations
        for_each_associated_foreign_instance do |foreign_instance|
          foreign_instance.push(self)
        end
      end

      def remove_from_associations
        for_each_associated_foreign_instance do |foreign_instance|
          foreign_instance.delete(self.id)
        end
      end

      def add_to_indices
        self.class.indices.each do |name|
          index = Index.new(self.class, name, send(name))
          index.insert(self.id)
        end
      end
      
      def delete_from_indices(attributes)
        attributes.each do |name, value|
          if self.class.indices.include?(name.to_sym)
            index = Index.new(self.class, name, self.send(name))
            index.delete(self.id)
          end
        end
      end
      
      def to_h
        self.class.attributes.keys.inject({}) do |h, attribute|
          h[attribute.to_sym] = self.send(attribute)
          h
        end
      end
      
      class << self
        attr_reader :attributes, :associations, :indices
        
        def create(attributes={})
          raise DuplicateKeyError, "Duplicate value for #{self} 'id'" if Tractor.redis.sismember("#{self}:all", attributes[:id])
          m = new(attributes)
          m.save
          m
        end
        
        def exists?(id)
          Tractor.redis.sismember("#{self}:all", id)
        end

        def find_by_id(id)
          obj_data = Tractor.redis["#{self}:#{id}"]
          return nil if obj_data.nil?
          parser = Yajl::Parser.new
          new(parser.parse(obj_data))
        end

        # use method missing to do craziness, or define a find_by on each index (BETTER)
        def find_by_attribute(name, value)
          raise MissingIndexError, "No index on '#{name}'" unless indices.include?(name)
          find({name => value})
        end

        def find(options = {})
          return [] if options.empty?
          unions = []
          sets = options.map do |name, value|
            if value.is_a?(Array) && value.any?
              unions << union_name = "#{value}-#{Time.now.to_f}"
              Tractor.redis.sunionstore(union_name, *value.map{|v| Index.key_for(self, name, v) })
              union_name
            else
              Index.key_for(self, name, value)
            end
          end
          ids = Tractor.redis.sinter(*sets) || []
          Tractor.redis.del(unions.join(","))
          ids.map {|id| find_by_id(id) }
        end
        
        def attribute(name, options={})
          options[:map] = name unless options[:map]
          attributes[name] = options
          setter(name, options[:type])
          getter(name, options[:type])
          index(name) if options[:index]
        end
        
        def index(name)
          indices << name unless indices.include?(name)
        end
        
        # make an assumption about the foreign_key... probably bad :)
        def association(name, klass)
          foreign_key_name = "#{self.to_s.gsub(/^.*::/, '').downcase}_id"
          klass.associations[self.name] = {:foreign_key_name => foreign_key_name, :set_name => name}
          define_method(name) do
            @association_store[name] = Association.new("#{self.class}:#{self.id}:#{name}", klass)
          end
        end
        
        def ids
          Tractor.redis.smembers("#{self}:all") || []
        end
        
        def count
          ids.size
        end
        
        def all
          ids.inject([]){|a, id| a << find_by_id(id); a }
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

        def for_each_associated_foreign_instance
          self.class.associations.each do |association_owner_class_name, association_attributes|
            foreign_klass = Object.module_eval(association_owner_class_name)
            foreign_key = self.send(association_attributes[:foreign_key_name])
            foreign_instance = foreign_klass.find_by_id(foreign_key)
            yield(foreign_instance.send(association_attributes[:set_name]))
          end
        end

    end
  end
end
