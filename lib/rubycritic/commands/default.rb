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
      end

      def execute
        if Config.compare_between_branches  
          switch_to_base_branch_and_compare
          switch_to_feature_branch_and_compare
          compare_code_quality
        else
          report(critique)
          status_reporter
        end
      end

      def switch_to_base_branch_and_compare
        p '============ Base Branch ============='
        `git checkout #{Config.base_branch}`
        Config.base_branch_score = critique.score
      end

      def switch_to_feature_branch_and_compare
        p '============ Feature Branch ============='
        `git checkout #{Config.feature_branch}`
        Config.feature_branch_score = critique.score
        `git checkout #{Config.base_branch}`
      end

      def compare_code_quality
        p 'Base branch score:' + Config.base_branch_score.to_s
        p 'Feature branch score:' + Config.feature_branch_score.to_s
        Config.base_branch_score > Config.feature_branch_score ? Config.quality_flag = false : Config.quality_flag = true
        status_reporter.status_message = Config.quality_flag ? 'GOOOOOOOOD' : 'BAAAAAAAD'
        status_reporter
      end

      def critique
        analysed_modules = AnalysersRunner.new(paths).run
        RevisionComparator.new(paths).set_statuses(analysed_modules)
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
