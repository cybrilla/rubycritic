# frozen_string_literal: true
require 'test_helper'
require 'rubycritic/commands/compare'
require 'rubycritic/cli/options'
require 'rubycritic/configuration'

describe RubyCritic::Command::Compare do

  describe 'with default options passing two branches' do
    before do
      @options = RubyCritic::Cli::Options.new(['-b', 'base_branch,feature_branch']).parse.to_h
    end

    it 'with -b option withour pull request id' do
      @options[:base_branch].must_equal 'base_branch'
      @options[:feature_branch].must_equal 'feature_branch'
      @options[:compare_between_branches].must_equal true
      @options[:mode].must_equal :compare_branches
    end
  end

  describe 'with default options passing two branches and pull request id' do
    before do
      @options = RubyCritic::Cli::Options.new(['-b', 'base_branch,feature_branch,1']).parse.to_h
    end

    it 'with -b option withour pr_id' do
      @options[:base_branch].must_equal 'base_branch'
      @options[:feature_branch].must_equal 'feature_branch'
      @options[:compare_between_branches].must_equal true
      @options[:mode].must_equal :compare_branches
      @options[:merge_request_id].must_equal 1
    end
  end
end
