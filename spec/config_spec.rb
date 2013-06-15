require 'yaml'
require 'spec_helper'

require_relative '../lib/tmux-connector/config_handler'


shared_examples "config test" do |config_name|
  let(:input) { configs[config_name]["input"] }
  let(:expected) do
    r = configs[config_name]["expected"]
    %w[ regex reject-regex ].each { |e| r[e] = Regexp.new r[e] if r[e] }
    r
  end

  it "process_config returns correct value" do
    configuration = input
    TmuxConnector.process_config! configuration
    configuration.should == expected
  end
end

describe "Configuration file" do
  let(:configs) do
    YAML.load_file(File.expand_path '../fixtures/configs.yml', __FILE__)
  end

  describe "minimal" do
    it_should_behave_like "config test", 'minimal'
  end

  describe "optional elements" do
    describe "reject-regex" do
      it_should_behave_like "config test", 'reject'
    end

    describe "name" do
      it_should_behave_like "config test", 'name'
    end

    describe "merge-groups" do
      it_should_behave_like "config test", 'merge'
    end

    describe "layout" do
      it_should_behave_like "config test", 'layout-default'
      it_should_behave_like "config test", 'layout-group'
      it_should_behave_like "config test", 'layout-both'
    end

    describe "multiple hosts" do
      it_should_behave_like "config test", 'multiple-hosts'
    end

    describe "panes without hosts" do
      it_should_behave_like "config test", 'hostless'
      it_should_behave_like "config test", 'hostless-merge'
    end
  end
end
