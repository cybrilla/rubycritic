# frozen_string_literal: true
require 'test_helper'
require 'rubycritic/commands/compare'
require 'rubycritic/cli/options'
require 'rubycritic/configuration'
require 'rubycritic/source_control_systems/git'

describe RubyCritic::Command::Compare do

  describe 'compare' do
    it 'should compare two files of different branch' do
      object = RubyCritic::SourceControlSystem::Git
      object.stubs(:switch_branch).with(:branch) do |arg|
        File.open('test/samples/compare_file.rb', 'w') {|file| file.truncate(0) }
        File.open('test/samples/compare_file.rb', 'w') {|o| o.puts File.readlines("test/samples/#{arg}_file.rb")}
        if arg == 'base_branch'
          true
        elsif arg == 'feature_branch'
          true
        end
      end
      options = RubyCritic::Cli::Options.new(['-b', 'base_branch,feature_branch', '-t', '10', 'test/samples/compare_file.rb']).parse.to_h
      RubyCritic::Config.set(options)
      status_reporter = RubyCritic::Command::Compare.new(options).execute
      status_reporter.score.must_equal 6.25
      status_reporter.status_message.must_equal 'Score: 6.25'
    end
  end

  describe 'with default options passing two branches' do
    before do
      @options = RubyCritic::Cli::Options.new(['-b', 'base_branch,feature_branch']).parse.to_h
    end

    it 'with -b option withour pull request id' do
      @options[:base_branch].must_equal 'base_branch'
      @options[:feature_branch].must_equal 'feature_branch'
      @options[:mode].must_equal :compare_branches
    end
  end

  describe 'create cost hash from analysed modules collection' do
    subject { RubyCritic::AnalysedModulesCollection.new(paths, base_analysed_modules) }

    context 'with analysed_modules_collection create cost hash' do
      let(:paths) { %w(test/samples/empty.rb  test/samples/unparsable.rb) }
      let(:base_analysed_modules) { [::RubyCritic::AnalysedModule.new(pathname: Pathname.new('test/samples/empty.rb'), name: 'empty', smells: [], churn: 2, committed_at: Time.now, complexity: 200, duplication: 10, methods_count: 20),
                                ::RubyCritic::AnalysedModule.new(pathname: Pathname.new('test/samples/unparsable.rb'), name: 'unparsable', smells: [], churn: 2, committed_at: Time.now, complexity: 100, duplication: 10, methods_count: 12)
                             ] }
      let(:feature_analysed_modules) { [::RubyCritic::AnalysedModule.new(pathname: Pathname.new('test/samples/empty.rb'), name: 'empty', smells: [], churn: 2, committed_at: Time.now, complexity: 200, duplication: 10, methods_count: 20),
                                ::RubyCritic::AnalysedModule.new(pathname: Pathname.new('test/samples/unparsable.rb'), name: 'unparsable', smells: [], churn: 2, committed_at: Time.now, complexity: 135, duplication: 10, methods_count: 12)
                             ] }

      it 'creates hash of file names and scores of it' do
        result_hash = {empty: 8, unparsable: 4}
        cost_hash = {}
        subject.each do |analysed_module|
          cost_hash.merge!({ "#{analysed_module.name}": analysed_module.cost }) 
        end
        cost_hash.must_equal result_hash
      end

      it 'compares between two hashes to get degraded files' do
        base_branch_result_hash = {empty: 8, unparsable: 4}
        base_branch_analysed_modules_collection = RubyCritic::AnalysedModulesCollection.new(paths, base_analysed_modules)
        base_branch_hash = {}
        base_branch_analysed_modules_collection.each do |analysed_module|
          base_branch_hash.merge!({ "#{analysed_module.name}": analysed_module.cost }) 
        end
        base_branch_hash.must_equal base_branch_result_hash
        feature_branch_result_hash = {empty: 8, unparsable: 5}
        feature_branch_analysed_modules_collection = RubyCritic::AnalysedModulesCollection.new(paths, feature_analysed_modules)
        feature_branch_hash = {}
        feature_branch_analysed_modules_collection.each do |analysed_module|
          feature_branch_hash.merge!({ "#{analysed_module.name}": analysed_module.cost }) 
        end
        feature_branch_hash.must_equal feature_branch_result_hash
        files_affected = []
        feature_branch_hash.each do |k,v|
          files_affected << k.to_s if !base_branch_hash[k.to_sym].nil? && base_branch_hash[k.to_sym] < v
        end
        files_affected.count.must_equal 1
        files_affected.first.must_equal 'unparsable'
      end
    end
  end
end
