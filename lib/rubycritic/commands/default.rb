# frozen_string_literal: true
require 'rubycritic/source_control_systems/base'
require 'rubycritic/analysers_runner'
require 'rubycritic/revision_comparator'
require 'rubycritic/reporter'
require 'rubycritic/commands/base'

module RubyCritic
  module Command
    class Default < Base
      def initialize(options)
        super
        @paths = options[:paths]
        Config.source_control_system = SourceControlSystem::Base.create
        @base_branch_hash = {}
        @feature_branch_hash = {}
        @files_affected = []
        @new_files = []
        @deleted_files = []
        @analysed_modules
      end

      def execute
        if Config.compare_between_branches  
          switch_to_base_branch_and_compare
          switch_to_feature_branch_and_compare
          get_degraded_files
          get_file_details
          defected_modules = @analysed_modules.where(@files_affected)
          paths = defected_modules.map { |mod| mod.path }
          analysed_modules = AnalysedModulesCollection.new(paths, defected_modules)
          Reporter.generate_report(analysed_modules)
          compare_code_quality
        else
          report(critique)
          status_reporter
        end
      end

      def switch_to_base_branch_and_compare
        `git checkout #{Config.base_branch}`
        Config.base_branch_score = critique('base_hash', true).score
      end

      def switch_to_feature_branch_and_compare
        `git checkout #{Config.feature_branch}`
        Config.feature_branch_score = critique('feature_hash', true).score
        `git checkout #{Config.base_branch}`
      end

      def compare_code_quality
        p 'Base branch score:' + Config.base_branch_score.to_s
        p 'Feature branch score:' + Config.feature_branch_score.to_s
        p "#{@new_files.count} New Files Addded" 
        p "#{@deleted_files.count} Files Deleted" 
        Config.base_branch_score > Config.feature_branch_score ? Config.quality_flag = false : Config.quality_flag = true
        status_reporter.status_message = Config.quality_flag ? "GOOOOOOOOD" : "BAAAAAAAD #{@files_affected} files degraded."
        status_reporter
      end

      def get_degraded_files
        @feature_branch_hash.each do |k,v|
          @files_affected << k.to_s if @base_branch_hash[k.to_sym] < v
        end
      end

      def get_file_details
        if (@feature_branch_hash.size > @base_branch_hash.size)
          difference = @feature_branch_hash.to_a - @base_branch_hash.to_a
          @new_files = Hash[*difference.flatten].keys
        else
          difference = @base_branch_hash.to_a - @feature_branch_hash.to_a
          @deleted_files = Hash[*difference.flatten].keys
        end
      end

      def critique(cost_hash = nil, code_analysis = false)
        analysed_modules = AnalysersRunner.new(paths).run
        @analysed_modules = analysed_modules
        build_cost_hash(cost_hash, analysed_modules) if code_analysis
        RevisionComparator.new(paths).set_statuses(analysed_modules)
      end

      def build_cost_hash(cost_hash, analysed_modules)
        complexity_hash = get_hash(cost_hash)
        analysed_modules.each do |analysed_module|
          complexity_hash.merge!({ "#{analysed_module.name}": analysed_module.cost }) 
        end
      end

      def get_hash(cost_hash)
        return @base_branch_hash if cost_hash == 'base_hash'
        return @feature_branch_hash if cost_hash == 'feature_hash'
      end

      def report(analysed_modules)
        Reporter.generate_report(analysed_modules)
        status_reporter.score = analysed_modules.score
      end

      private

      attr_reader :paths, :status_reporter
    end
  end
end
