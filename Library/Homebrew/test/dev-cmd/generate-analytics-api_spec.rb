# typed: strict
# frozen_string_literal: true

require "cmd/shared_examples/args_parse"
require "dev-cmd/generate-analytics-api"

RSpec.describe Homebrew::DevCmd::GenerateAnalyticsApi do
  it_behaves_like "parseable arguments"

  it "generates InfluxDB reports without local Git histories or GitHub queries" do
    stub_const("Utils::Analytics::API::CATEGORIES", ["install"])
    stub_const("Utils::Analytics::API::DAYS", ["30"])
    allow(GitHub::API).to receive(:open_rest).and_raise("Unexpected GitHub query")
    allow(Utils::Analytics::Repository).to receive(:new).and_raise("Unexpected Git history")
    allow(Utils::Analytics::Influx).to receive(:new).and_return(
      instance_double(Utils::Analytics::Influx, setup_python: nil, venv_python: Pathname("python"),
                       influxdb_query_script: Pathname("query.py"), query: [{ total_count: 42 }]),
    )
    allow(SystemCommand).to receive(:safe_system).with(Pathname("python"), Pathname("query.py"), "--check")
    mktmpdir.cd do
      described_class.new(["--influx"]).run

      expect(JSON.parse(Pathname("_data/analytics/install/30d.json").read)).to eq("total_count" => 42)
    end
  end

  it "generates release analytics without InfluxDB or GitHub queries" do
    allow_any_instance_of(Utils::Analytics::Influx).to receive(:setup_python).and_raise("Unexpected InfluxDB setup")
    allow(GitHub::API).to receive(:open_rest).and_raise("Unexpected GitHub query")
    allow(Utils::Analytics::Releases).to receive(:new).and_return(
      instance_double(Utils::Analytics::Releases, report: { "releases" => [{ "version" => "1.0.0" }] }),
    )
    mktmpdir.cd do
      described_class.new(["--releases"]).run

      expect(JSON.parse(Pathname("_data/analytics/releases/history.json").read))
        .to eq("releases" => [{ "version" => "1.0.0" }])
    end
  end

  [0, -1, 1001].each do |limit|
    it "rejects a download limit of #{limit}" do
      T.bind(self, RSpec::Core::ExampleGroup)
      expect { described_class.new(["--github-packages-limit=#{limit}"]).github_packages_limit }
        .to raise_error(UsageError, /between 1 and 1000/)
    end
  end

  it "rejects an all-formula download limit before starting network generation" do
    allow_any_instance_of(Utils::Analytics::Influx).to receive(:setup_python).and_raise("Unexpected network setup")

    expect { described_class.new(["--github-packages-limit=all"]).run }
      .to raise_error(UsageError, /between 1 and 1000/)
  end
end
