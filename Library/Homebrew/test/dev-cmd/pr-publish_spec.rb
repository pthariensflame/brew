# typed: strict
# frozen_string_literal: true

require "cmd/shared_examples/args_parse"
require "dev-cmd/pr-publish"

RSpec.describe Homebrew::DevCmd::PrPublish do
  it_behaves_like "parseable arguments"

  describe "#run" do
    it "requests autosquash only for pull requests with the `autosquash` label" do
      allow(GitHub).to receive(:pull_request_labels).and_return([])
      allow(GitHub).to receive(:pull_request_labels).with("Homebrew", "homebrew-core", "1").and_return(["autosquash"])
      allow(GitHub).to receive(:workflow_dispatch_event)
      expect(GitHub).to receive(:workflow_dispatch_event)
        .with("Homebrew", "homebrew-core", "publish-commit-bottles.yml", "main",
              hash_including(autosquash: false, pull_request: "2"))

      described_class.new(["1", "2"]).run
    end

    it "passes `--warn-on-upload-failure` to the workflow" do
      allow(GitHub).to receive(:pull_request_labels).and_return([])
      expect(GitHub).to receive(:workflow_dispatch_event)
        .with("Homebrew", "homebrew-core", "publish-commit-bottles.yml", "main",
              autosquash: false, pull_request: "12345", warn_on_upload_failure: true)

      described_class.new(["--warn-on-upload-failure", "12345"]).run
    end

    it "ignores the retired large runner label while preserving autosquash" do
      allow(GitHub).to receive(:pull_request_labels).and_return(["autosquash", "large-bottle-upload"])
      expect(GitHub).to receive(:workflow_dispatch_event)
        .with("Homebrew", "homebrew-core", "publish-commit-bottles.yml", "main",
              autosquash: true, pull_request: "12345")

      described_class.new(["12345"]).run
    end
  end
end
