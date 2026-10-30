# typed: strict
# frozen_string_literal: true

require "utils/github"
require "utils/output"
require "json"

# GitHub Releases client.
class GitHubReleases
  include Context
  include Utils::Output::Mixin

  URL_REGEX = %r{https://github\.com/([\w-]+)/([\w-]+)?/releases/download/(.+)}

  sig { params(bottles_hash: T::Hash[String, T.untyped]).void }
  def upload_bottles(bottles_hash)
    bottle_count = bottles_hash.count
    bottles_hash.each_value.with_index do |bottle_hash, index|
      root_url = bottle_hash["bottle"]["root_url"]
      url_match = root_url.match URL_REGEX
      _, user, repo, tag = *url_match

      # Ensure a release is created or reused. Bottles are uploaded to a draft
      # release which is published afterwards, so that uploads also work on
      # repositories with immutable releases enabled, where assets cannot be
      # added to a release after it has been published.
      release, draft_release = find_or_create_release(user, repo, tag)

      # Upload bottles as release assets.
      bottle_hash["bottle"]["tags"].each_value do |tag_hash|
        remote_file = tag_hash["filename"]
        local_file = tag_hash["local_filename"]
        odebug "Uploading #{remote_file}"
        GitHub.upload_release_asset user, repo, release["id"], local_file:, remote_file:
      end

      # Publish the release (and thereby create its tag) now that all bottle
      # assets have been uploaded.
      if draft_release
        GitHub.create_or_update_release(user, repo, tag, id: release["id"], draft: false)
      end

      next if bottle_count < 3

      uploaded_count = index + 1
      ohai "Upload progress: #{uploaded_count} formula(e) uploaded, #{bottle_count - uploaded_count} remaining"
    end
  end

  private

  # Returns a release to upload bottle assets to, together with whether it is
  # a draft release that still needs to be published after uploading. An
  # existing release for the tag is reused so that failed uploads can be
  # repaired. Otherwise, a new draft release is created, reusing a leftover
  # draft release for the tag if there is one.
  sig {
    params(user: String, repo: String, tag: String)
      .returns([T::Hash[String, T.untyped], T::Boolean])
  }
  def find_or_create_release(user, repo, tag)
    release = begin
      rel = GitHub.get_release user, repo, tag
      odebug "Existing GitHub release \"#{tag}\" found"
      rel
    rescue GitHub::API::HTTPNotFoundError
      nil
    end
    return [release, false] if release

    begin
      odebug "Creating new draft GitHub release \"#{tag}\""
      [GitHub.create_or_update_release(user, repo, tag, draft: true), true]
    rescue GitHub::API::Error
      # Draft releases are not returned by the tag lookup above, so a leftover
      # draft release for this tag makes creating a new release fail.
      release = GitHub.get_draft_release user, repo, tag
      raise if release.nil?

      odebug "Existing draft GitHub release \"#{tag}\" found"
      [release, true]
    end
  end
end
