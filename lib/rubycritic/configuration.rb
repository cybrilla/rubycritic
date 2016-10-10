# frozen_string_literal: true
module RubyCritic
  class Configuration
    attr_reader :root
    attr_accessor :source_control_system, :mode, :format, :deduplicate_symlinks,
                  :suppress_ratings, :open_with, :no_browser, :base_branch, :feature_branch, :compare_between_branches ,:base_branch_score, :feature_branch_score, :quality_flag

    def set(options)
      self.mode = options[:mode] || :default
      self.root = options[:root] || 'tmp/rubycritic'
      self.format = options[:format] || :html
      self.deduplicate_symlinks = options[:deduplicate_symlinks] || false
      self.suppress_ratings = options[:suppress_ratings] || false
      self.open_with = options[:open_with]
      self.no_browser = options[:no_browser]
      self.base_branch = options[:base_branch]
      self.feature_branch = options[:feature_branch]
      self.compare_between_branches = options[:compare_between_branches]
    end

    def root=(path)
      @root = File.expand_path(path)
    end
  end

  module Config
    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.set(options = {})
      configuration.set(options)
    end

    def self.method_missing(method, *args, &block)
      configuration.public_send(method, *args, &block)
    end

    def self.respond_to_missing?(symbol, include_all = false)
      configuration.respond_to_missing?(symbol) || super
    end
  end
end
