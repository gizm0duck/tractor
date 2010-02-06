module Tractor
  module Model
    class Mapper < Tractor::Model::Base
      class << self
        
        def value_mapper(server_instance)
          attributes = {}
          self.attributes.each do |name, options|
            server_value = server_instance.respond_to?(options[:map]) ? server_instance.send(options[:map]) : nil
            attributes[name] = server_value
          end
          attributes
        end
        
      end
    end
  end
end