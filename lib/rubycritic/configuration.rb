# frozen_string_literal: true
require 'rubycritic/source_control_systems/base'

module RubyCritic
  class Configuration
    attr_reader :root
    attr_accessor :source_control_system, :mode, :format, :deduplicate_symlinks,
                  :suppress_ratings, :open_with, :no_browser, :base_branch,
                  :feature_branch, :base_branch_score, :feature_branch_score,
                  :base_root_directory, :feature_root_directory,
                  :build_root_directory, :threshold_score, :base_branch_collection,
                  :feature_branch_collection

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
      self.threshold_score = options[:threshold_score]
    end

    def root=(path)
      @root = File.expand_path(path)
    end

    def source_control_present?
      source_control_system &&
        !source_control_system.is_a?(SourceControlSystem::Double)
    end
  end

  module Config
    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.set(options = {})
      configuration.set(options)
    end

    def self.compare_branches_mode?
      Config.mode == :compare_branches || Config.mode == :ci
    end

    def self.build_mode?
      (Config.mode == :compare_branches || Config.mode == :ci) && !Config.no_browser
    end

    def self.method_missing(method, *args, &block)
      configuration.public_send(method, *args, &block)
    end

    def self.respond_to_missing?(symbol, include_all = false)
      configuration.respond_to_missing?(symbol) || super
    end
  end
end
