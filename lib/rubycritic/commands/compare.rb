# frozen_string_literal: true
require 'rubycritic/source_control_systems/base'
require 'rubycritic/analysers_runner'
require 'rubycritic/revision_comparator'
require 'rubycritic/reporter'
require 'rubycritic/commands/base'
require 'httparty'
require 'yaml'

module RubyCritic
  module Command
    class Compare < Base
      def initialize(options)
        super
        @paths = options[:paths]
        Config.source_control_system = SourceControlSystem::Base.create
        @base_branch_hash = {}
        @feature_branch_hash = {}
        @files_affected = []
        @analysed_modules
        @number
        @code_index_file_location
        @app_settings = load_yml
      end

      def execute
        compare_branches
        status_reporter
      end

      def compare_branches
        update_build_number
        set_root_paths
        switch_to_base_branch_and_compare
        switch_to_feature_branch_and_compare
        feature_branch_analysis
        push_comments_to_svn if Config.merge_request_id
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

      def switch_to_base_branch_and_compare
        switch_branch(Config.base_branch)
        critic = critique('base_branch_hash')
        Config.base_branch_score = critic.score
        Config.root = base_root_directory
        Config.base_branch_flag = Config.no_browser = true
        report(critic)
        Config.base_branch_flag = false
      end

      def switch_to_feature_branch_and_compare
        switch_branch(Config.feature_branch)
        critic = critique('feature_branch_hash')
        Config.feature_branch_score = critic.score
        Config.root = feature_root_directory
        Config.feature_branch_flag = Config.no_browser = true
        report(critic)
        Config.feature_branch_flag = false
        switch_branch(Config.base_branch)
      end

      def feature_branch_analysis
        Config.no_browser = false
        defected_modules = @analysed_modules.where(degraded_files)
        analysed_modules = AnalysedModulesCollection.new(defected_modules.map(&:path), defected_modules)
        Config.root = build_directory
        Config.set_location = Config.build_flag = true
        @code_index_file_location = Reporter.generate_report(analysed_modules)
        score_difference
      end

      def score_difference
        Config.difference_score =
          if Config.base_branch_score > Config.feature_branch_score
            (Config.base_branch_score - Config.feature_branch_score).round(2)
          else
            (Config.feature_branch_score - Config.base_branch_score).round(2)
          end
      end

      def push_comments_to_svn
        if @app_settings['github'] 
          push_comments_to_github 
        elsif @app_settings['gitlab'] 
          push_comments_to_gitlab
        end
      end

      def push_comments_to_github
        user_name = @app_settings['github_user_name']
        repo_name = @app_settings['github_repo_name']
        api_key = @app_settings['github_api_key']
        merge_request_id = Config.merge_request_id
        unless [user_name, repo_name, api_key, merge_request_id].all?(&:nil?)
          HTTParty.post("https://api.github.com/repos/#{user_name}/#{repo_name}/issues/#{merge_request_id}/comments",
          :body => {'body' => build_note}.to_json,
          :headers => { 'Authorization' => "token #{api_key}", 'User-Agent' => "#{repo_name}" })
        end
      end

      def push_comments_to_gitlab
        app_id = @app_settings['gitlab_app_id']
        secret = @app_settings['gitlab_secret']
        gitlab_url = @app_settings['gitlab_url']
        merge_request_id = Config.merge_request_id
        unless [app_id, secret, gitlab_url, merge_request_id].all?(&:nil?)
          HTTParty.post("#{gitlab_url}/api/v3/projects/#{app_id}/merge_requests/#{merge_request_id}/notes",
          :query => {'body' => build_note},
          :headers => {'Private-Token' => secret} )
        end
      end

      def build_note  
        ERB.new(File.read(File.join(File.dirname(__FILE__), '../generators/html/templates/note.html.erb')), nil, '-').result(binding).delete("\n") + "\n"
      end

      def compare_code_quality
        Config.base_branch_score > Config.feature_branch_score ? Config.quality_flag = false : Config.quality_flag = true
        status_reporter.status_message = Config.quality_flag ? "GOOOOOOOOD" : "BAAAAAAAD #{@files_affected} files degraded."
        build_details
        compare_threshold
      end

      def compare_threshold
        `exit 1` if mark_jenkins_build_fail 
      end

      def mark_jenkins_build_fail
        [@app_settings['app_threshold'], @app_settings['difference_threshold']].all?(&:nil?) ? false : (Config.base_branch_score < @app_settings['app_threshold'] || (Config.base_branch_score - Config.feature_branch_score) > @app_settings['difference_threshold']) 
      end

      def base_root_directory
        "tmp/rubycritic/#{Config.base_branch}"
      end

      def feature_root_directory
        "tmp/rubycritic/#{Config.feature_branch}"
      end

      def build_directory
        "tmp/rubycritic/builds/build_#{@number}"
      end

      def switch_branch(branch)
        `git checkout #{branch}`
      end

      def load_yml
        YAML.load_file('config/rubycritic_app_settings.yml')
      end

      def build_details
        details = "Base branch (#{Config.base_branch}) score: " + Config.base_branch_score.to_s + "\n"
        details += "Feature branch (#{Config.feature_branch}) score: " + Config.feature_branch_score.to_s + "\n"
        details += status_reporter.status_message
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
        analysed_modules = AnalysersRunner.new(paths).run
        @analysed_modules = analysed_modules
        build_cost_hash(cost_hash, analysed_modules)
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
