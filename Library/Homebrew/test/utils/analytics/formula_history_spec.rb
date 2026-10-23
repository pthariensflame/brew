# typed: true
# frozen_string_literal: true

require "utils/analytics/formula_history"

RSpec.describe Utils::Analytics::FormulaHistory do
  let(:repository) { CoreTap.instance.path }
  let(:path) { repository/"Formula/historical.rb" }
  let(:cache) { mktmpdir/"checkpoint.json" }
  let(:report) { described_class.new(repository, cache:) }
  let(:git) do
    ["git", "-C", repository.to_s, "-c", "user.name=Test", "-c", "user.email=test@example.test",
     "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null"]
  end

  before do
    allow(Time).to receive(:now).and_return(Time.utc(2025, 5, 31))
    (repository/"Formula/h").mkpath
    Utils.safe_popen_read(*git, "init", "--quiet")
    update("2023-01-01", "1.0")
    update("2024-01-02", "1.1")
    update("2025-01-02", "1.1.1")
    update("2025-02-02", "1.1.1", revision: 1)
    update("2025-03-02", "1.1.1", revision: 1, rebuild: 1)
  end

  def update(date, version, revision: 0, rebuild: 0)
    path.dirname.mkpath
    path.write <<~RUBY
      class Historical < Formula
        url "https://brew.sh/historical-#{version}.tar.gz"
        revision #{revision}
        bottle do
          rebuild #{rebuild}
        end
      end
    RUBY
    commit(date)
  end

  def commit(date)
    ENV["GIT_AUTHOR_DATE"] = ENV["GIT_COMMITTER_DATE"] = "#{date}T12:00:00Z"
    Utils.safe_popen_read(*git, "add", "-A", "Formula/historical.rb", "Formula/h")
    Utils.safe_popen_read(*git, "commit", "--quiet", "-m", "Update historical formula")
  end

  it "counts version updates once across platforms and separates revisions from rebuilds" do
    data = report.report(start_year: 2024)

    expect(data).to include(
      "complete" => true, "maintenance" => { "updated" => 1 },
      "rows" => include(include("period" => "current", "versions" => 2, "minor" => 1, "patch" => 1,
                                "revision_bumps" => 1, "bottle_rebuilds" => 1, "unreadable" => 0))
    )
  end

  it "does not reload Git blobs or historical formulae for an unchanged checkpoint" do
    report.report(start_year: 2024)
    expect(report).not_to receive(:sources)

    report.report(start_year: 2024)
  end

  it "reads only commits after the persistent checkpoint on an update" do
    previous = report.report(start_year: 2024).fetch("revision")
    update("2025-04-02", "2.0")
    head = Utils.safe_popen_read(*git, "rev-parse", "HEAD").strip
    expect(report).to receive(:commits).with("#{previous}..#{head}").and_call_original

    report.report(start_year: 2024)
  end

  it "preserves version identity across a sharding rename" do
    report.report(start_year: 2024)
    (repository/"Formula/h").mkpath
    path.rename(repository/"Formula/h/historical.rb")
    commit("2025-04-02")

    expect(report.report(start_year: 2024).fetch("rows"))
      .to include(include("period" => "current", "versions" => 2, "added" => 0, "removed" => 0))
  end

  it "resumes an interrupted initial backfill without marking it complete" do
    first = report.report(start_year: 2024, max_seconds: 0)
    resumed = described_class.new(repository, cache:).report(start_year: 2024)

    expect([first.fetch("complete"), first.fetch("rows").first.fetch("versions"), resumed.fetch("complete")])
      .to eq([false, nil, true])
  end

  it "invalidates old checkpoint formats before deserialising their state" do
    cache.write(JSON.generate({ signature: "old-format", start_year: 2024, packages: nil }))

    expect(report.report(start_year: 2024)).to include("complete" => true)
  end

  it "reports unreadable historical changes rather than treating them as no update" do
    path.write("this is invalid Ruby (")
    commit("2025-04-02")

    expect(report.report(start_year: 2024).fetch("rows"))
      .to include(include("period" => "2025", "unreadable" => 1))
  end
end
