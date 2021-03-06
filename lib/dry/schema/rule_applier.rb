require 'dry/initializer'

require 'dry/schema/constants'
require 'dry/schema/config'
require 'dry/schema/result'
require 'dry/schema/messages'
require 'dry/schema/message_compiler'

module Dry
  module Schema
    # Applies rules defined within the DSL
    #
    # @api private
    class RuleApplier
      extend Dry::Initializer

      # @api private
      param :rules

      # @api private
      option :config, default: proc { Config.new }

      # @api private
      option :message_compiler, default: proc { MessageCompiler.new(Messages.setup(config)) }

      # @api private
      def call(input)
        results = EMPTY_ARRAY.dup

        rules.each do |name, rule|
          next if input.error?(name)
          result = rule.(input)
          results << result if result.failure?
        end

        input.concat(results)
      end

      # @api private
      def to_ast
        [:set, rules.values.map(&:to_ast)]
      end
    end
  end
end
