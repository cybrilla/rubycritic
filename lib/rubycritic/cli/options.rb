# frozen_string_literal: true
require 'optparse'
require 'rubycritic/browser'

module RubyCritic
  module Cli
    class Options
      def initialize(argv)
        @argv = argv
        self.parser = OptionParser.new
      end

      # rubocop:disable Metrics/MethodLength
      def parse
        parser.new do |opts|
          opts.banner = 'Usage: rubycritic [options] [paths]'

          opts.on('-p', '--path [PATH]', 'Set path where report will be saved (tmp/rubycritic by default)') do |path|
            @root = path
          end

          opts.on('-b', '--branch [BASE_BRANCH,FEATURE_BRANCH,GITLAB_PR_ID(optional)]' , 'Set branches') do |branches|
            self.base_branch = String(branches.split(',')[0].strip)
            self.feature_branch = String(branches.split(',')[1].strip)
            self.merge_request_id = Integer(branches.split(',')[2].strip) rescue nil
            self.compare_between_branches = true
            self.mode = :compare_branches
          end

          opts.on(
            '-f', '--format [FORMAT]',
            [:html, :json, :console],
            'Report smells in the given format:',
            '  html (default; will open in a browser)',
            '  json',
            '  console'
          ) do |format|
            self.format = format
          end

          opts.on('-s', '--minimum-score [MIN_SCORE]', 'Set a minimum score') do |min_score|
            self.minimum_score = Integer(min_score)
          end

          opts.on('-m', '--mode-ci', 'Use CI mode (faster, but only analyses last commit)') do
            self.mode = :ci
          end

          opts.on('--deduplicate-symlinks', 'De-duplicate symlinks based on their final target') do
            self.deduplicate_symlinks = true
          end

          opts.on('--suppress-ratings', 'Suppress letter ratings') do
            self.suppress_ratings = true
          end

          opts.on('--no-browser', 'Do not open html report with browser') do
            self.no_browser = true
          end

          opts.on_tail('-v', '--version', "Show gem's version") do
            self.mode = :version
          end

          opts.on_tail('-h', '--help', 'Show this message') do
            self.mode = :help
          end
        end.parse!(@argv)
        self
      end

      def to_h
        {
          mode: mode,
          root: root,
          format: format,
          deduplicate_symlinks: deduplicate_symlinks,
          paths: paths,
          suppress_ratings: suppress_ratings,
          help_text: parser.help,
          minimum_score: minimum_score || 0,
          no_browser: no_browser,
          base_branch: base_branch,
          feature_branch: feature_branch,
          compare_between_branches: compare_between_branches,
          merge_request_id: merge_request_id
        }
      end

      private

      attr_accessor :mode, :root, :format, :deduplicate_symlinks,
                    :suppress_ratings, :minimum_score, :no_browser, :parser, :base_branch, :feature_branch, :compare_between_branches, :merge_request_id
      def paths
        if @argv.empty?
          ['.']
        else
          @argv
        end
      end
    end
  end
end
