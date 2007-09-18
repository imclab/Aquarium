require 'aquarium/utils'
  
def bad_attributes message, options
  raise Aquarium::Utils::InvalidOptions.new("Invalid attributes. " + message + ". Options were: #{options.inspect}")
end

module Aquarium
  module Aspects
    class JoinPoint

      class Context
        attr_accessor :advice_kind, :advised_object, :parameters, :block_for_method, :returned_value, :raised_exception, :proceed_proc

        alias :target_object  :advised_object
        alias :target_object= :advised_object=
        
        def initialize options
          update options
          assert_valid options
        end

        def update options
          options.each do |key, value|
            instance_variable_set "@#{key}".intern, value
          end
        end
    
        def proceed enclosing_join_point, *args, &block
          raise "JoinPoint#proceed can only be called if @proceed_proc is set." unless @proceed_proc
          args = parameters if (args.nil? or args.size == 0)
          enclosing_join_point.context.block_for_method = block if block 
          proceed_proc.call enclosing_join_point, *args
        end
        protected :proceed
        
        alias :to_s :inspect
    
        # We require the same object id, not just equal objects.
        def <=> other
          return 0 if object_id == other.object_id 
          result = self.class <=> other.class 
          return result unless result == 0
          result = (self.advice_kind.nil? && other.advice_kind.nil?) ? 0 : self.advice_kind <=> other.advice_kind 
          return result unless result == 0
          result = (self.advised_object.object_id.nil? && other.advised_object.object_id.nil?) ? 0 : self.advised_object.object_id <=> other.advised_object.object_id 
          return result unless result == 0
          result = (self.parameters.nil? && other.parameters.nil?) ? 0 : self.parameters <=> other.parameters 
          return result unless result == 0
          result = (self.returned_value.nil? && other.returned_value.nil?) ? 0 : self.returned_value <=> other.returned_value 
          return result unless result == 0
          (self.raised_exception.nil? && other.raised_exception.nil?) ? 0 : self.raised_exception <=> other.raised_exception
        end
    
        def eql? other
          (self <=> other) == 0
        end

        alias :==  :eql?
        alias :=== :eql?
    
        protected
    
        def assert_valid options
          bad_attributes("Must specify an :advice_kind", options)    unless advice_kind
          bad_attributes("Must specify an :advised_object", options) unless advised_object
          bad_attributes("Must specify a :parameters", options)      unless parameters
        end    
      end

      %w[type object].each do |attr|
        class_eval <<-EOF
          # Deprecated, as JoinPoint#type overrides Module#type in a non-substitutable way!
          # JoinPoint#target_#{attr} will be removed in the next release.
          # Use JoinPoint#target_#{attr} instead
          def #{attr}
            p "WARNING: JoinPoint##{attr} is deprecated. It will be removed in the next release."
            target_#{attr}
          end
          # Deprecated
          def #{attr}= new_#{attr}
            p "WARNING: JoinPoint##{attr}= is deprecated. It will be removed in the next release."
            target_#{attr}= new_#{attr}
          end
        EOF
      end
      
      attr_accessor :target_type, :target_object, :method_name, :visibility, :context
      
      # For "symmetry" with JoinPoint#target_type
      alias_method  :object, :target_object

      # For "symmetry" with JoinPoint#target_type=
      alias_method  :object=, :target_object=
      
      def instance_method?
        @instance_method
      end
      
      def initialize options = {}
        @target_type     = options[:type]
        @target_object   = options[:object]
        @method_name     = options[:method_name] || options[:method]
        @instance_method = options[:instance_method]
        class_method = options[:class_method].nil? ? false : options[:class_method]
        @instance_method = (!class_method) if @instance_method.nil?
        @visibility = Aquarium::Utils::MethodUtils.visibility(type_or_object, @method_name, class_or_instance_method_flag)
        assert_valid options
      end
  
      def type_or_object
        @target_type || @target_object
      end
      
      # TODO while convenient, it couples advice-type information where it doesn't belong!
      def proceed *args, &block
        context.method(:proceed).call self, *args, &block
      end

      def make_current_context_join_point context_options
        new_jp = dup
        if new_jp.context.nil?
          new_jp.context = JoinPoint::Context.new context_options
        else
          new_jp.context = context.dup
          new_jp.context.update context_options
        end
        new_jp
      end

      # We require the same object id, not just equal objects.
      def <=> other
        return 0 if object_id == other.object_id 
        result = self.class <=> other.class 
        return result unless result == 0
        result = (self.target_type.nil? && other.target_type.nil?) ? 0 : self.target_type.to_s <=> other.target_type.to_s 
        return result unless result == 0
        result = (self.target_object.object_id.nil? && other.target_object.object_id.nil?) ? 0 : self.target_object.object_id <=> other.target_object.object_id 
        result = self.target_object.object_id <=> other.target_object.object_id
        return result unless result == 0
        result = (self.method_name.nil? && other.method_name.nil?) ? 0 : self.method_name.to_s <=> other.method_name.to_s 
        return result unless result == 0
        result = self.instance_method? == other.instance_method?
        return 1 unless result == true
        result = (self.context.nil? && other.context.nil?) ? 0 : self.context <=> other.context 
        return result
      end

      def eql? other
        return (self <=> other) == 0
      end
  
      alias :==  :eql?
      alias :=== :eql?
  
      def inspect
        "JoinPoint: {type = #{target_type.inspect}, object = #{target_object.inspect}, method_name = #{method_name}, instance_method? #{instance_method?}, context = #{context.inspect}}"
      end
  
      alias :to_s :inspect

  
      protected
  
      # Since JoinPoints can be declared for non-existent methods, tolerate "nil" for the visibility.
      def assert_valid options
        error_message = ""
        error_message << "Must specify a :method_name. "            unless method_name
        error_message << "Must specify either a :type or :object. " unless (target_type or  target_object)
        error_message << "Can't specify both a :type or :object. "  if     (target_type and target_object)
        bad_attributes(error_message, options) if error_message.length > 0
      end

      def class_or_instance_method_flag
        @instance_method ? :instance_method_only : :class_method_only
      end
    
      public
  
      NIL_OBJECT = Aquarium::Utils::NilObject.new  
    end
  end
end
