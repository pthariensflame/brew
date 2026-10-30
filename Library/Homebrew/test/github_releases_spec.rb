# typed: strict
# frozen_string_literal: true

require "github_releases"

RSpec.describe GitHubReleases do
  describe "#upload_bottles" do
    it "reports progress when uploading many bottles" do
      events = []
      bottles_hash = %w[foo bar baz].to_h do |formula_name|
        [formula_name, {
          "bottle" => {
            "root_url" => "https://github.com/homebrew/homebrew-core/releases/download/test",
            "tags"     => {
              "arm64"  => {
                "filename"       => "#{formula_name}-arm64.bottle.tar.gz",
                "local_filename" => "#{formula_name}-arm64.local.bottle.tar.gz",
              },
              "x86_64" => {
                "filename"       => "#{formula_name}-x86_64.bottle.tar.gz",
                "local_filename" => "#{formula_name}-x86_64.local.bottle.tar.gz",
              },
            },
          },
        }]
      end
      allow(GitHub).to receive(:get_release).and_return({ "id" => 123 })
      expect(GitHub).not_to receive(:create_or_update_release)
      allow(GitHub).to receive(:upload_release_asset) do |_, _, _, local_file:, remote_file:|
        events << "Uploaded #{remote_file} from #{local_file}"
      end
      github_releases = described_class.new
      allow(github_releases).to receive(:ohai) { |message| events << message }

      github_releases.upload_bottles(bottles_hash)

      expect(events).to eq([
        "Uploaded foo-arm64.bottle.tar.gz from foo-arm64.local.bottle.tar.gz",
        "Uploaded foo-x86_64.bottle.tar.gz from foo-x86_64.local.bottle.tar.gz",
        "Upload progress: 1 formula(e) uploaded, 2 remaining",
        "Uploaded bar-arm64.bottle.tar.gz from bar-arm64.local.bottle.tar.gz",
        "Uploaded bar-x86_64.bottle.tar.gz from bar-x86_64.local.bottle.tar.gz",
        "Upload progress: 2 formula(e) uploaded, 1 remaining",
        "Uploaded baz-arm64.bottle.tar.gz from baz-arm64.local.bottle.tar.gz",
        "Uploaded baz-x86_64.bottle.tar.gz from baz-x86_64.local.bottle.tar.gz",
        "Upload progress: 3 formula(e) uploaded, 0 remaining",
      ])
    end

    it "does not report progress when uploading fewer than three bottles" do
      events = []
      bottles_hash = %w[foo bar].to_h do |formula_name|
        [formula_name, {
          "bottle" => {
            "root_url" => "https://github.com/homebrew/homebrew-core/releases/download/test",
            "tags"     => {
              "arm64" => {
                "filename"       => "#{formula_name}-arm64.bottle.tar.gz",
                "local_filename" => "#{formula_name}-arm64.local.bottle.tar.gz",
              },
            },
          },
        }]
      end
      allow(GitHub).to receive(:get_release).and_return({ "id" => 123 })
      allow(GitHub).to receive(:upload_release_asset) do |_, _, _, local_file:, remote_file:|
        events << "Uploaded #{remote_file} from #{local_file}"
      end
      github_releases = described_class.new
      allow(github_releases).to receive(:ohai) { |message| events << message }

      github_releases.upload_bottles(bottles_hash)

      expect(events).to eq([
        "Uploaded foo-arm64.bottle.tar.gz from foo-arm64.local.bottle.tar.gz",
        "Uploaded bar-arm64.bottle.tar.gz from bar-arm64.local.bottle.tar.gz",
      ])
    end

    it "creates a draft release, uploads bottles and publishes the release afterwards" do
      events = []
      bottles_hash = {
        "foo" => {
          "bottle" => {
            "root_url" => "https://github.com/homebrew/homebrew-core/releases/download/test",
            "tags"     => {
              "arm64" => {
                "filename"       => "foo-arm64.bottle.tar.gz",
                "local_filename" => "foo-arm64.local.bottle.tar.gz",
              },
            },
          },
        },
      }
      release = { "id" => 123, "draft" => true }
      create_calls = []
      allow(GitHub).to receive(:get_release).and_raise(GitHub::API::HTTPNotFoundError.new("not found"))
      allow(GitHub).to receive(:create_or_update_release) do |user, repo, tag, **kwargs|
        create_calls << [user, repo, tag, kwargs]
        release
      end
      allow(GitHub).to receive(:upload_release_asset) do |_, _, _, local_file:, remote_file:|
        events << "Uploaded #{remote_file} from #{local_file}"
      end
      github_releases = described_class.new
      allow(github_releases).to receive(:ohai) { |message| events << message }

      github_releases.upload_bottles(bottles_hash)

      expect(events).to eq(["Uploaded foo-arm64.bottle.tar.gz from foo-arm64.local.bottle.tar.gz"])
      expect(create_calls).to eq([
        ["homebrew", "homebrew-core", "test", { draft: true }],
        ["homebrew", "homebrew-core", "test", { id: 123, draft: false }],
      ])
    end

    it "reuses a leftover draft release when creating a new release fails" do
      events = []
      bottles_hash = {
        "foo" => {
          "bottle" => {
            "root_url" => "https://github.com/homebrew/homebrew-core/releases/download/test",
            "tags"     => {
              "arm64" => {
                "filename"       => "foo-arm64.bottle.tar.gz",
                "local_filename" => "foo-arm64.local.bottle.tar.gz",
              },
            },
          },
        },
      }
      draft_release = { "id" => 456, "draft" => true }
      allow(GitHub).to receive(:get_release).and_raise(GitHub::API::HTTPNotFoundError.new("not found"))
      allow(GitHub).to receive(:create_or_update_release)
        .with("homebrew", "homebrew-core", "test", draft: true)
        .and_raise(GitHub::API::Error.new("tag_name already exists"))
      allow(GitHub).to receive(:create_or_update_release)
        .with("homebrew", "homebrew-core", "test", id: 456, draft: false)
        .and_return(draft_release)
      allow(GitHub).to receive(:get_draft_release).and_return(draft_release)
      allow(GitHub).to receive(:upload_release_asset) do |_, _, release_id, local_file:, remote_file:|
        events << "Uploaded #{remote_file} from #{local_file} to release #{release_id}"
      end
      github_releases = described_class.new
      allow(github_releases).to receive(:ohai) { |message| events << message }

      github_releases.upload_bottles(bottles_hash)

      expect(events).to eq(["Uploaded foo-arm64.bottle.tar.gz from foo-arm64.local.bottle.tar.gz " \
                            "to release 456"])
    end
  end
end
