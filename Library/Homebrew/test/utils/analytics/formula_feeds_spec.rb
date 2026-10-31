# typed: true
# frozen_string_literal: true

require "utils/analytics/formula_feeds"

RSpec.describe Utils::Analytics::FormulaFeeds do
  let(:root) { mktmpdir }
  let(:repository) { root/"core" }
  let(:commit_dates) { (1..).lazy.map { |index| Time.utc(2026, 1, 1) + (60 * index) } }

  before do
    repository.mkpath
    git("init", "--quiet", "--initial-branch=main")
    git("config", "user.name", "Feed tests")
    git("config", "user.email", "feeds@example.test")
    git("config", "commit.gpgsign", "false")
    git("config", "core.hooksPath", File::NULL)
  end

  def git(*args, path: repository)
    stdout, stderr, status = Open3.capture3("git", "-C", path.to_s, *args)
    raise stderr unless status.success?

    stdout.strip
  end

  def commit(message = "Change formula")
    git("add", ".")
    date = commit_dates.next.iso8601
    _stdout, stderr, status = Open3.capture3(
      { "GIT_AUTHOR_DATE" => date, "GIT_COMMITTER_DATE" => date },
      "git", "-C", repository.to_s, "commit", "--quiet", "-m", message
    )
    raise stderr unless status.success?

    git("rev-parse", "HEAD")
  end

  def formula(name = "example", version: "1.0", revision: 0, rebuild: 0, extra: "")
    path = repository/"Formula"/"#{name}.rb"
    path.dirname.mkpath
    path.write <<~RUBY
      class #{name.split("-").map(&:capitalize).join} < Formula
        desc "Tools & utilities"
        homepage "https://example.test"
        url "https://example.test/#{name}-#{version}.tar.gz"
        version "#{version}"
        sha256 "#{"a" * 64}"
        license "MIT"
        revision #{revision}
        bottle do
          rebuild #{rebuild}
        end
        #{extra}
      end
    RUBY
    path
  end

  def feeds
    described_class.new(repository).generate
  end

  it "uses merged changes once and excludes bottles, resources, aliases and renames" do
    path = formula
    added = commit
    git("switch", "--quiet", "-c", "release")
    formula(version: "1.1")
    commit
    formula(version: "1.2")
    commit
    git("switch", "--quiet", "main")
    git("merge", "--quiet", "--no-ff", "release", "-m", "Merge release")
    released = git("rev-parse", "HEAD")
    formula(version: "1.2", revision: 1)
    revised = commit
    formula(version: "1.2", revision: 1, rebuild: 1)
    commit
    formula(version: "1.2", revision: 1, rebuild: 1, extra: <<~RUBY)
      resource "helper" do
        url "https://example.test/helper-2.0.tar.gz"
        sha256 "#{"b" * 64}"
      end
    RUBY
    commit
    renamed_path = repository/"Formula/e/example.rb"
    renamed_path.dirname.mkpath
    FileUtils.mv(path, renamed_path)
    (repository/"Aliases").mkpath
    File.symlink("../Formula/e/example.rb", repository/"Aliases/alias")
    commit

    result = feeds
    expect(result.fetch("new").map { |entry| entry.fetch("commit") }).to eq([added])
    expect(result.fetch("updated").map { |entry| entry.fetch("commit") }).to eq([revised, released])
    expect(result.fetch("updated").map { |entry| entry.fetch("versions") }).to eq([["1.2_1"], ["1.2"]])
    expect(result.fetch("updated").first.fetch("date")).to eq((Time.utc(2026, 1, 1) + (4 * 60)).iso8601)
    expect(feeds).to eq(result)
  end

  it "counts a platform-specific version change once" do
    formula(extra: "on_linux do\n    version \"2.0\"\n  end")
    commit
    formula(extra: "on_linux do\n    version \"2.1\"\n  end")
    commit
    result = feeds
    expect(result.fetch("updated").length).to eq(1)
    expect(result.fetch("updated").first.fetch("versions")).to eq(["1.0", "2.1"])
  end

  def edited_move(version)
    path = formula(extra: (1..40).map { |index| "# Original source line #{index}" }.join("\n"))
    added = commit
    formula(version:, extra: (1..40).map { |index| "# Replacement source line #{index}" }.join("\n"))
    moved_path = repository/"Formula/e/example.rb"
    moved_path.dirname.mkpath
    FileUtils.mv(path, moved_path)
    moved = commit
    expect(git("diff", "HEAD^", "HEAD", "--name-status", "--find-renames=50%").lines.map(&:strip))
      .to contain_exactly("A\tFormula/e/example.rb", "D\tFormula/example.rb")
    [added, moved, feeds]
  end

  it "recognizes a heavily edited move without a version change" do
    added, _moved, result = edited_move("1.0")

    expect([result.fetch("new").map { |entry| entry.fetch("commit") }, result.fetch("updated")])
      .to eq([[added], []])
  end

  it "recognizes a version update during a heavily edited move" do
    added, moved, result = edited_move("2.0")

    expect([result.fetch("new").map { |entry| entry.fetch("commit") }, result.fetch("updated")])
      .to match([[added], [include("commit" => moved, "versions" => ["2.0"])]])
  end

  it "treats a formula reintroduced after a separate deletion as an addition" do
    path = formula
    added = commit
    path.unlink
    commit
    formula(version: "2.0")
    reintroduced = commit

    result = feeds
    expect(result.fetch("new").map { |entry| entry.fetch("commit") }).to eq([reintroduced, added])
    expect(result.fetch("updated")).to be_empty
  end

  it "validates each formula path even when source blobs are identical" do
    path = formula
    FileUtils.cp(path, repository/"Formula/zother.rb")
    commit
    expect { feeds }.to raise_error(%r{Cannot read formula metadata for Formula/zother.rb})
  end

  it "continues through history pages containing no formula changes" do
    formula
    commit
    100.times do |index|
      (repository/"README").write(index.to_s)
      commit
    end
    formula(version: "2.0")
    commit
    result = feeds
    expect(result.fetch("new").map { |entry| entry.fetch("versions") }).to eq([["1.0"]])
    expect(result.fetch("updated").map { |entry| entry.fetch("versions") }).to eq([["2.0"]])
  end

  it "caps the feeds at 50 additions and 500 updates even within a single commit" do
    501.times { |index| formula("package-#{index}") }
    commit
    501.times { |index| formula("package-#{index}", version: "2.0") }
    commit
    result = feeds
    expect(result.fetch("new").length).to eq(50)
    expect(result.fetch("updated").length).to eq(500)
    expect(result.fetch("updated").map { |entry| entry.fetch("id") }.uniq.length).to eq(500)

    formula("fresh")
    formula("package-0", version: "3.0")
    commit
    refreshed = feeds
    expect(refreshed.fetch("new").first.fetch("name")).to eq("fresh")
    expect(refreshed.fetch("updated").first.fetch("versions")).to eq(["3.0"])
    { "new" => 50, "updated" => 500 }.each do |type, limit|
      expect(refreshed.fetch(type).length).to eq(limit)
      previous_ids = result.fetch(type).map { |entry| entry.fetch("id") }
      refreshed_ids = refreshed.fetch(type).map { |entry| entry.fetch("id") }
      expect((previous_ids & refreshed_ids).length).to eq(limit - 1)
    end
  end

  it "fails when formula metadata cannot be read" do
    path = formula
    commit
    path.write("class Example < Formula\n  invalid_metadata!\nend\n")
    commit
    expect { feeds }.to raise_error(/Cannot read formula metadata/)
  end

  it "rejects a shallow checkout instead of treating its boundary as additions" do
    formula
    commit
    formula(version: "2.0")
    commit
    shallow = root/"shallow"
    git("clone", "--quiet", "--depth=1", "file://#{repository}", shallow.to_s)
    expect { described_class.new(shallow).generate }.to raise_error(/unshallow/)
  end
end
