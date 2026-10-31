# typed: true
# frozen_string_literal: true

require "cmd/shared_examples/args_parse"
require "dev-cmd/generate-formula-feeds"

RSpec.describe Homebrew::DevCmd::GenerateFormulaFeeds do
  let(:arguments) { ["--repository=#{repository}", "--output=#{output_path}"] }
  let(:path) { repository/"Formula/example.rb" }
  let(:output_path) { mktmpdir/"feeds.json" }
  let(:repository) { mktmpdir }

  before do
    system "git", "-C", repository, "init", "--quiet", exception: true
    write_formula("1.0")
  end

  it_behaves_like "parseable arguments"

  def write_formula(version)
    path.dirname.mkpath
    path.write <<~RUBY
      class Example < Formula
        url "https://example.test/example-#{version}.tar.gz"
        sha256 "#{"a" * 64}"
      end
    RUBY
    system "git", "-C", repository, "add", ".", exception: true
    system "git", "-C", repository, "-c", "user.name=Feed tests", "-c", "user.email=feeds@example.test",
           "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null",
           "commit", "--quiet", "-m", "Update formula", exception: true
  end

  it "writes entries through the command", :integration_test do
    expect { brew "generate-formula-feeds", *arguments }
      .to output(/Generated 1 new and 0 updated formula entries/).to_stdout
  end

  it "writes stable JSON for a selected revision" do
    revision = Utils.safe_popen_read("git", "-C", repository, "rev-parse", "HEAD").strip
    write_formula("2.0")
    described_class.new([*arguments, "--revision=#{revision}"]).run
    original = output_path.read
    described_class.new([*arguments, "--revision=#{revision}"]).run

    expect([JSON.parse(original), output_path.read]).to match([
      { "revision" => revision, "new" => [include("name" => "example", "versions" => ["1.0"])], "updated" => [] },
      original,
    ])
  end

  it "limits additions and updates independently" do
    (repository/"Formula/other.rb").write(path.read.sub("class Example", "class Other"))
    write_formula("2.0")
    write_formula("3.0")
    write_formula("4.0")
    described_class.new([*arguments, "--new-limit=1", "--updated-limit=2"]).run

    expect(JSON.parse(output_path.read)).to include(
      "new"     => [include("versions" => ["1.0"])],
      "updated" => [include("versions" => ["4.0"]), include("versions" => ["3.0"])],
    )
  end

  it "allows zero entries for both feeds" do
    described_class.new([*arguments, "--new-limit=0", "--updated-limit=0"]).run

    expect(JSON.parse(output_path.read)).to include("new" => [], "updated" => [])
  end

  it "rejects invalid limits before writing output" do
    output_path.write("previous data")
    invalid_limits = ["-1", "1.5", "invalid", ""]
    %w[new updated].each do |feed|
      invalid_limits.each do |limit|
        expect { described_class.new([*arguments, "--#{feed}-limit=#{limit}"]).run }
          .to raise_error(UsageError, /`--#{feed}-limit` must be a non-negative integer/)
      end
    end
    expect(output_path.read).to eq("previous data")
  end

  it "replaces the output without modifying the file held by existing readers" do
    output_path.write("previous data")
    output_path.open do |previous|
      described_class.new(arguments).run

      expect([previous.read, JSON.parse(output_path.read).fetch("new").first.fetch("name")])
        .to eq(["previous data", "example"])
    end
  end

  it "leaves the previous output intact when formula metadata cannot be read" do
    output_path.write("previous data")
    path.write("class Example < Formula\n  invalid_metadata!\nend\n")
    system "git", "-C", repository, "add", ".", exception: true
    system "git", "-C", repository, "-c", "user.name=Feed tests", "-c", "user.email=feeds@example.test",
           "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null",
           "commit", "--quiet", "-m", "Invalid formula", exception: true

    expect { described_class.new(arguments).run }.to raise_error(/Cannot read formula metadata/)
    expect(output_path.read).to eq("previous data")
  end
end
