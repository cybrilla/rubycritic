# frozen_string_literal: true
require 'rubycritic/source_control_systems/base'
require 'rubycritic/analysers_runner'
require 'rubycritic/revision_comparator'
require 'rubycritic/reporter'
require 'rubycritic/commands/base'
require 'rubycritic/commands/default'

module RubyCritic
  module Command
    class Compare < Default
      def initialize(options)
        super
        @base_branch_hash = {}
        @feature_branch_hash = {}
        @files_affected = []
        @analysed_modules = []
        @number = 0
        @code_index_file_location = ''
      end

      def execute
        Config.no_browser = true
        compare_branches
        status_reporter.score = (Config.base_branch_score - Config.feature_branch_score).abs
        status_reporter
      end

      private

      attr_reader :paths, :status_reporter

      def compare_branches
        update_build_number
        set_root_paths
        switch_and_compare(Config.base_branch, 'base_branch', base_root_directory)
        switch_and_compare(Config.feature_branch, 'feature_branch', feature_root_directory)
        feature_branch_analysis
        compare_code_quality
      end

      def update_build_number
        build_file_location = '/tmp/build_count.txt'
        File.new(build_file_location, "a") unless (File.exist?(build_file_location))
        @number = File.open(build_file_location).readlines.first.to_i + 1 
        File.write(build_file_location, @number)
      end

      def set_root_paths
        Config.base_root_directory = Pathname.new(base_root_directory)
        Config.feature_root_directory = Pathname.new(feature_root_directory)
        Config.build_root_directory = Pathname.new(build_directory)
      end

      def switch_and_compare(branch, branch_type, root_directory)
        SourceControlSystem::Git.switch_branch(branch)
        critic = critique("#{branch_type}_hash")
        set_scores(branch_type, critic.score)
        Config.root = root_directory
        report(critic)
      end

      def set_scores(branch_type, score)
        branch_type == 'base_branch' ? Config.base_branch_score = score : Config.feature_branch_score = score
      end

      def feature_branch_analysis
        Config.no_browser = false
        defected_modules = @analysed_modules.where(degraded_files)
        analysed_modules = AnalysedModulesCollection.new(defected_modules.map(&:path), defected_modules)
        Config.root = build_directory
        Config.set_location = true
        @code_index_file_location = Reporter.generate_report(analysed_modules)
      end

      def compare_code_quality
        build_details
        compare_threshold
      end

      def compare_threshold
        `exit 1` if mark_build_fail? 
      end

      def mark_build_fail?
        threshold_values_set? && threshold_reached?
      end

      def threshold_values_set?
        Config.threshold_score > 0
      end

      def threshold_reached?
        (Config.base_branch_score - Config.feature_branch_score).abs > Config.threshold_score
      end

      def base_root_directory
        "tmp/rubycritic/compare/#{Config.base_branch}"
      end

      def feature_root_directory
        "tmp/rubycritic/compare/#{Config.feature_branch}"
      end

      def build_directory
        "tmp/rubycritic/compare/builds/build_#{@number}"
      end

      def build_details
        details = "Base branch (#{Config.base_branch}) score: " + Config.base_branch_score.to_s + "\n"
        details += "Feature branch (#{Config.feature_branch}) score: " + Config.feature_branch_score.to_s + "\n"
        File.open("#{Config.build_root_directory}/build_details.txt", 'w') {|f| f.write(details) }
      end

      def degraded_files
        @feature_branch_hash.each do |k,v|
          @files_affected << k.to_s if !@base_branch_hash[k.to_sym].nil? && @base_branch_hash[k.to_sym] < v
        end
        @files_affected
      end

      def build_cost_hash(cost_hash, analysed_modules)
        complexity_hash = eval("@#{cost_hash}")
        analysed_modules.each do |analysed_module|
          complexity_hash.merge!({ "#{analysed_module.name}": analysed_module.cost }) 
        end
      end

      def critique(cost_hash)
        @analysed_modules = AnalysersRunner.new(paths).run
        build_cost_hash(cost_hash, @analysed_modules)
        RevisionComparator.new(paths).set_statuses(@analysed_modules)
      end
    end
  end
end
