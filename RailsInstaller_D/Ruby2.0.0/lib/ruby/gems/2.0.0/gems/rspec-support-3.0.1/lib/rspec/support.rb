module RSpec
  module Support
    # @api private
    #
    # Defines a helper method that is optimized to require files from the
    # named lib. The passed block MUST be `{ |f| require_relative f }`
    # because for `require_relative` to work properly from within the named
    # lib the line of code must be IN that lib.
    #
    # `require_relative` is preferred when available because it is always O(1),
    # regardless of the number of dirs in $LOAD_PATH. `require`, on the other
    # hand, does a linear O(N) search over the dirs in the $LOAD_PATH until
    # it can resolve the file relative to one of the dirs.
    def self.define_optimized_require_for_rspec(lib, &require_relative)
      name = "require_rspec_#{lib}"

      if Kernel.respond_to?(:require_relative)
        (class << self; self; end).__send__(:define_method, name) do |f|
          require_relative.call("#{lib}/#{f}")
        end
      else
        (class << self; self; end).__send__(:define_method, name) do |f|
          require "rspec/#{lib}/#{f}"
        end
      end
    end

    define_optimized_require_for_rspec(:support) { |f| require_relative(f) }
    require_rspec_support "version"
    require_rspec_support "ruby_features"

    # @api private
    KERNEL_METHOD_METHOD = ::Kernel.instance_method(:method)

    # @api private
    #
    # Used internally to get a method handle for a particular object
    # and method name.
    #
    # Includes handling for a few special cases:
    #
    #   - Objects that redefine #method (e.g. an HTTPRequest struct)
    #   - BasicObject subclasses that mixin a Kernel dup (e.g. SimpleDelegator)
    if RubyFeatures.supports_rebinding_module_methods?
      def self.method_handle_for(object, method_name)
        KERNEL_METHOD_METHOD.bind(object).call(method_name)
      end
    else
      def self.method_handle_for(object, method_name)
        if ::Kernel === object
          KERNEL_METHOD_METHOD.bind(object).call(method_name)
        else
          object.method(method_name)
        end
      end
    end

    if RUBY_PLATFORM == 'java'
      if Proc.method_defined?(:lambda?)
        def self.proc_to_lambda(block)
          return block if block.lambda?
          lambda(&block)
        end
      else
        def self.proc_to_lambda(block)
          lambda(&block)
        end
      end
    elsif respond_to?(:define_singleton_method)
      def self.proc_to_lambda(block)
        return block if block.lambda?

        obj = Object.new
        obj.define_singleton_method(:to_lambda, &block)
        obj.method(:to_lambda).to_proc
      end
    else # 1.8.7
      def self.proc_to_lambda(block)
        obj = Object.new
        (class << obj; self; end).__send__(:define_method, :to_lambda, &block)
        obj.method(:to_lambda).to_proc
      end
    end
  end
end
