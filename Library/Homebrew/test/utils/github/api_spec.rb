# typed: strict
# frozen_string_literal: true

require "utils/github"

RSpec.describe GitHub::API do
  describe "::github_cli_token" do
    it "uses the selected executable and timeout without printing lookup output" do
      expect(described_class).to receive(:system_command).with(
        Pathname("/trusted/bin/gh"), args: %w[auth token --hostname github.com],
        env: Utils::Path.formula_opt_bin_env("gh"), timeout: 10, print_stderr: false, debug: false, verbose: false
      ).and_return(instance_double(SystemCommand::Result,
                                   to_a: ["test-token\n", "", instance_double(Process::Status, success?: true)]))

      described_class.github_cli_token(executable: Pathname("/trusted/bin/gh"), timeout: 10)
    end
  end

  describe "::sleep_for_rate_limit" do
    it "sleeps for at least 1 second even if the rate limit has already reset" do
      exception = GitHub::API::RateLimitExceededError.new(
        "API rate limit exceeded", reset: Time.now.to_i - 10, resource: "core", limit: 5000
      )
      expect(described_class).to receive(:sleep).with(1)
      described_class.sleep_for_rate_limit(exception)
    end
  end
end
