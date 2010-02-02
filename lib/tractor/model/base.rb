module Tractor
  module Model
    class Base
      
      def initialize(attributes={})
        @attribute_store = {}
        attributes.each do |k,v|
          send("#{k}=", v)
        end
      end
      
      def save
        # write to redis (magic)
      end
      
      class << self
        attr_reader :attributes
        def attribute(name, options=[])
          attributes[name] = Array(options).empty? ? name : options
          mapping, type = options
          setter(name, mapping, type)
          getter(name, mapping, type)
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