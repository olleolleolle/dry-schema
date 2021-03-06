require 'pathname'
require 'concurrent/map'
require 'dry/equalizer'
require 'dry/configurable'

require 'dry/schema/constants'

module Dry
  module Schema
    module Messages
      # Abstract class for message backends
      #
      # @api public
      class Abstract
        extend Dry::Configurable
        include Dry::Equalizer(:config)

        DEFAULT_PATH = Pathname(__dir__).join('../../../../config/errors.yml').realpath.freeze

        setting :paths, [DEFAULT_PATH]
        setting :root, 'errors'.freeze
        setting :lookup_options, [:root, :predicate, :path, :val_type, :arg_type].freeze

        setting :lookup_paths, %w(
          %{root}.rules.%{path}.%{predicate}.arg.%{arg_type}
          %{root}.rules.%{path}.%{predicate}
          %{root}.%{predicate}.%{message_type}
          %{root}.%{predicate}.value.%{path}.arg.%{arg_type}
          %{root}.%{predicate}.value.%{path}
          %{root}.%{predicate}.value.%{val_type}.arg.%{arg_type}
          %{root}.%{predicate}.value.%{val_type}
          %{root}.%{predicate}.arg.%{arg_type}
          %{root}.%{predicate}
        ).freeze

        setting :arg_type_default, 'default'.freeze
        setting :val_type_default, 'default'.freeze

        setting :arg_types, Hash.new { |*| config.arg_type_default }.update(
          Range => 'range'
        )

        setting :val_types, Hash.new { |*| config.val_type_default }.update(
          Range => 'range',
          String => 'string'
        )

        # @api private
        def self.cache
          @cache ||= Concurrent::Map.new { |h, k| h[k] = Concurrent::Map.new }
        end

        # @api private
        attr_reader :config

        # @api private
        def initialize
          @config = self.class.config
        end

        # @api private
        def hash
          @hash ||= config.hash
        end

        # @api private
        def rule(name, options = {})
          path = "%{locale}.rules.#{name}"
          get(path, options) if key?(path, options)
        end

        # Retrieve a message
        #
        # @return [String]
        #
        # @api public
        def call(*args)
          cache.fetch_or_store(args.hash) do
            path, opts = lookup(*args)
            get(path, opts) if path
          end
        end
        alias_method :[], :call

        # Try to find a message for the given predicate and its options
        #
        # @api private
        def lookup(predicate, options = {})
          tokens = options.merge(
            root: options[:not] ? "#{root}.not" : root,
            predicate: predicate,
            arg_type: config.arg_types[options[:arg_type]],
            val_type: config.val_types[options[:val_type]],
            message_type: options[:message_type] || :failure
          )

          tokens[:path] = options[:rule] || Array(options[:path]).join(DOT)

          opts = options.select { |k, _| !config.lookup_options.include?(k) }

          path = lookup_paths(tokens).detect do |key|
            key?(key, opts) && get(key, opts).is_a?(String)
          end

          [path, opts]
        end

        # @api private
        def lookup_paths(tokens)
          config.lookup_paths.map { |path| path % tokens }
        end

        # Return a new message backend that will look for messages under provided namespace
        #
        # @param [Symbol,String] namespace
        #
        # @api public
        def namespaced(namespace)
         Dry::Schema::Messages::Namespaced.new(namespace, self)
        end

        # Return root path to messages file
        #
        # @return [Pathname]
        #
        # @api public
        def root
          config.root
        end

        # @api private
        def cache
          @cache ||= self.class.cache[self]
        end

        # @api private
        def default_locale
          :en
        end
      end
    end
  end
end
