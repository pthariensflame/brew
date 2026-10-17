# typed: strict
# frozen_string_literal: true

require "vulns"

RSpec.describe Homebrew::Vulns do
  describe ".select_vulnerable" do
    sig { returns(Formula) }
    let(:act) do
      formula("act") do
        T.bind(self, T.class_of(Formula))
        url "https://github.com/nektos/act/archive/refs/tags/v0.2.84.tar.gz"
      end
    end

    before do
      allow(act).to receive_messages(any_installed_prefix:  TEST_FIXTURE_DIR/"vulns",
                                     any_installed_version: PkgVersion.parse("0.2.80"))
      allow(Homebrew::Vulns::OSV).to receive_messages(
        query_batch:   [[{ "id" => "CVE-TEST" }]],
        vulnerability: { "id" => "CVE-TEST", "database_specific" => { "severity" => "HIGH" } },
      )
    end

    it "selects an installed formula with open vulnerabilities" do
      expect(described_class.select_vulnerable([act])).to eq([act])
    end

    it "excludes findings below the requested severity" do
      expect(described_class.select_vulnerable([act], severity: "critical")).to be_empty
    end

    it "rejects invalid severity even with no upgrade candidates" do
      expect { described_class.select_vulnerable([], severity: "urgent") }.to raise_error(UsageError)
    end

    it "rejects missing installed-source evidence before selecting upgrades" do
      allow(act).to receive(:any_installed_prefix).and_return(Pathname("/nonexistent"))
      expect { described_class.select_vulnerable([act]) }.to raise_error(/Incomplete vulnerability scan/)
    end

    it "rejects unsupported sources" do
      allow(act).to receive_messages(stable: nil, head: nil, homepage: nil, any_installed_prefix: nil)
      expect { described_class.select_vulnerable([act]) }.to raise_error(/Incomplete vulnerability scan/)
    end

    it "propagates advisory-service failures" do
      allow(Homebrew::Vulns::OSV).to receive(:query_batch).and_raise("advisory service unavailable")
      expect { described_class.select_vulnerable([act]) }.to raise_error("advisory service unavailable")
    end

    it "matches fully qualified formula identities" do
      allow(act).to receive(:full_name).and_return("example/tools/act")
      expect(described_class.select_vulnerable([act])).to eq([act])
    end
  end
end
