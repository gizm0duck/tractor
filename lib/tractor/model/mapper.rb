module Tractor
  module Model
    class Mapper < Tractor::Model::Base
      class << self
        attr_reader :dependencies
        
        def depends_on(klass, options = {})
          dependencies[klass] = options
          
          # set index by default on items that have a depends on
          #set_redis_index(klass, options[:key_name])
        end
        
        def representation_for(server_instance)
          if exists?(server_instance.id)
            update_from_instance(server_instance)
          else
            create_from_instance(server_instance)
          end
        end
        
        def find_from_instance(server_instance)
          self.find_by_id(server_instance.id)
        end
        
        def create_from_instance(server_instance)
          hydrate_attributes(server_instance) do |attributes|
            begin
              return self.create(attributes)
            rescue DuplicateKeyError
              return find_from_instance(server_instance)
            end
          end
        end
        
        def update_from_instance(server_instance)
          existing_record = find_from_instance(server_instance)
          raise "Cannot update an object that doesn't exist." unless existing_record
          
          hydrate_attributes(server_instance) do |attributes|
            return existing_record.update(attributes)
          end
        end
        
        def remove(server_id)
          obj_to_destroy = self.find_by_id(server_id)
          return false if obj_to_destroy.nil?
          obj_to_destroy.destroy
        end
        
        def hydrate_attributes(server_instance, hydrate_only=false, &block)
          attributes = attribute_mapper(server_instance)
          if hydrate_only
            ensure_dependencies_met(server_instance, hydrate_only, &block)
            block.call([self.to_s, attributes])
          else
            ensure_dependencies_met(server_instance, hydrate_only)
            yield attributes
          end
          return attributes
        end
        
        def attribute_mapper(server_instance)
          attributes = {}
          self.attributes.each do |name, options|
            server_value = server_instance.respond_to?(options[:map]) ? server_instance.send(options[:map]) : nil
            attributes[name] = server_value
          end
          attributes
        end
        
        def dependency_met_for?(server_instance, klass)
          !!klass.find_by_id(server_instance.send(dependencies[klass][:key_name]))
        end
        
        def dependencies_met?(server_instance)
          dependencies.each do |klass, options|
            return false unless dependency_met_for?(server_instance, klass)
          end
          return true
        end
        
        def ensure_dependencies_met(server_instance, hydrate_only=false, &block)
          
          return if !hydrate_only && dependencies_met?(server_instance)
          dependencies.each do |klass, options|
            if hydrate_only || klass.find_by_id(server_instance.send(options[:key_name])).nil?
              server_instances = server_instance.send(options[:method_name])
              server_instances = server_instances.is_a?(Array) ? server_instances : [server_instances]
              server_instances.each do |obj|
                if hydrate_only
                  klass.hydrate_attributes(obj, hydrate_only, &block)
                else
                  klass.create_from_instance(obj)
                end
              end
            end
          end
        end
        
        def dependencies
          @dependencies ||= {}
        end
      end
    end
  end
end