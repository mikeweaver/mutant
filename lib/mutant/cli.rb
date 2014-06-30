require 'optparse'

module Mutant

  # Comandline parser
  class CLI
    include Adamantium::Flat, Equalizer.new(:config)

    # Error raised when CLI argv is invalid
    Error = Class.new(RuntimeError)

    EXIT_FAILURE = 1
    EXIT_SUCCESS = 0

    # Run cli with arguments
    #
    # @param [Array<String>] arguments
    #
    # @return [Fixnum]
    #   the exit status
    #
    # @api private
    #
    def self.run(arguments)
      config = new(arguments).config
      runner = Runner::Config.run(config)
      runner.success? ? EXIT_SUCCESS : EXIT_FAILURE
    rescue Error => exception
      $stderr.puts(exception.message)
      EXIT_FAILURE
    end

    # Initialize objecct
    #
    # @param [Array<String>]
    #
    # @return [undefined]
    #
    # @api private
    #
    def initialize(arguments = [])
      @builder = Matcher::Builder.new(Env::Boot.new(Reporter::CLI.new($stderr), Cache.new))
      @debug = @fail_fast = @zombie = false
      @expected_coverage = 100.0
      @integration = Integration::Null.new
      parse(arguments)
      @config  = Config.new(
        zombie:            @zombie,
        debug:             @debug,
        matcher:           @builder.matcher,
        integration:       @integration,
        fail_fast:         @fail_fast,
        reporter:          Reporter::CLI.new($stdout),
        expected_coverage: @expected_coverage
      )
    end

    # Return config
    #
    # @return [Config]
    #
    # @api private
    #
    attr_reader :config

  private

    # Parse the command-line options
    #
    # @param [Array<String>] arguments
    #   Command-line options and arguments to be parsed.
    #
    # @raise [Error]
    #   An error occurred while parsing the options.
    #
    # @return [undefined]
    #
    # @api private
    #
    def parse(arguments)
      opts = OptionParser.new do |builder|
        builder.banner = 'usage: mutant STRATEGY [options] PATTERN ...'
        builder.separator('')
        add_environmental_options(builder)
        add_mutation_options(builder)
        add_filter_options(builder)
        add_debug_options(builder)
      end

      patterns =
        begin
          opts.parse!(arguments)
        rescue OptionParser::ParseError => error
          raise(Error, error.message, error.backtrace)
        end

      parse_matchers(patterns)
    end

    # Parse matchers
    #
    # @param [Array<String>] patterns
    #
    # @return [undefined]
    #
    # @api private
    #
    def parse_matchers(patterns)
      raise Error, 'No patterns given' if patterns.empty?
      patterns.each do |pattern|
        @builder.add_match_expression(Expression.parse(pattern))
      end
    end

    # Add environmental options
    #
    # @param [Object] opts
    #
    # @return [undefined]
    #
    # @api private
    #
    def add_environmental_options(opts)
      opts.separator('')
      opts.separator('Environment:')
      opts.on('--zombie', 'Run mutant zombified') do
        @zombie = true
      end.on('-I', '--include DIRECTORY', 'Add DIRECTORY to $LOAD_PATH') do |directory|
        $LOAD_PATH << directory
      end.on('-r', '--require NAME', 'Require file with NAME') do |name|
        require(name)
      end
    end

    # Use plugin
    #
    # FIXME: For now all plugins are strategies. Later they could be anything that allows "late integration".
    #
    # @param [String] name
    #
    # @return [undefined]
    #
    # @api private
    #
    def use(name)
      require "mutant/#{name}"
      @integration = Integration.lookup(name).new
    rescue LoadError
      $stderr.puts("Cannot load plugin: #{name.inspect}")
      raise
    end

    # Add options
    #
    # @param [OptionParser] opts
    #
    # @return [undefined]
    #
    # @api private
    #
    def add_mutation_options(opts)
      opts.separator(EMPTY_STRING)
      opts.separator('Options:')

      opts.on('--score COVERAGE', 'Fail unless COVERAGE is not reached exactly') do |coverage|
        @expected_coverage = Float(coverage)
      end.on('--use STRATEGY', 'Use STRATEGY for killing mutations') do |runner|
        use(runner)
      end
    end

    # Add filter options
    #
    # @param [OptionParser] opts
    #
    # @return [undefined]
    #
    # @api private
    #
    def add_filter_options(opts)
      opts.on('--ignore-subject PATTERN', 'Ignore subjects that match PATTERN') do |pattern|
        @builder.add_subject_ignore(Expression.parse(pattern))
      end
      opts.on('--code CODE', 'Scope execution to subjects with CODE') do |code|
        @builder.add_subject_selector(:code, code)
      end
    end

    # Add debug options
    #
    # @param [OptionParser] opts
    #
    # @return [undefined]
    #
    # @api private
    #
    def add_debug_options(opts)
      opts.on('--fail-fast', 'Fail fast') do
        @fail_fast = true
      end.on('--version', 'Print mutants version') do
        puts("mutant-#{Mutant::VERSION}")
        Kernel.exit(0)
      end.on('-d', '--debug', 'Enable debugging output') do
        @debug = true
      end.on_tail('-h', '--help', 'Show this message') do
        puts(opts)
        exit
      end
    end
  end # CLI
end # Mutant
