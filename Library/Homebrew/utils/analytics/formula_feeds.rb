# typed: strict
# frozen_string_literal: true

require "utils/analytics/formula_history"

module Utils
  module Analytics
    # Collects bounded formula feeds from first-parent Git history.
    class FormulaFeeds
      class Change < T::Struct
        const :commit, String
        const :timestamp, Integer
        const :path, String
        const :after, String
        prop :old_path, String
        prop :before, T.nilable(String)
        prop :added, T::Boolean
      end

      Entry = T.type_alias { T::Hash[String, T.any(String, T::Array[String])] }
      Builds = T.type_alias { T::Hash[String, FormulaHistory::Build] }
      LIMITS = T.let({ "new" => 50, "updated" => 500 }.freeze, T::Hash[String, Integer])
      BATCH_SIZE = 100

      sig { params(repository: Pathname, revision: String, limits: T::Hash[String, Integer]).void }
      def initialize(repository, revision: "HEAD", limits: LIMITS)
        @history = T.let(FormulaHistory.new(repository), FormulaHistory)
        @revision = T.let(@history.git("rev-parse", "--verify", "#{revision}^{commit}"), String)
        @limits = limits
        @builds = T.let({}, T::Hash[[String, String], Builds])
      end

      sig { returns(T::Hash[String, T.any(String, T::Array[Entry])]) }
      def generate
        if @history.git("rev-parse", "--is-shallow-repository") == "true"
          raise "Formula feeds require complete Git history; unshallow the core checkout first"
        end

        feeds = @limits.to_h { |name, _limit| [name, T.let([], T::Array[Entry])] }
        offset = 0
        until feeds.all? { |name, entries| entries.length >= @limits.fetch(name) }
          changes = changes(offset)
          break if changes.nil?

          selected = changes.select do |change|
            feed = change.added ? "new" : "updated"
            feeds.fetch(feed).length < @limits.fetch(feed)
          end
          blobs = selected.flat_map { |change| [change.before, change.after] }.compact.uniq
          sources = blobs.empty? ? {} : @history.sources(blobs)
          selected.each do |change|
            feed = change.added ? "new" : "updated"
            next if feeds.fetch(feed).length >= @limits.fetch(feed)

            after = builds(change.path, change.after, sources)
            before_blob = change.before
            before = before_blob ? builds(change.old_path, before_blob, sources) : nil
            next if before && after.none? do |platform, build|
              old = before.fetch(platform)
              old.version && build.version && (old.version != build.version || build.revision > old.revision)
            end

            feeds.fetch(feed) << {
              "id"       => "#{change.commit}:#{change.path}",
              "name"     => File.basename(change.path, ".rb"),
              "date"     => Time.at(change.timestamp).utc.iso8601,
              "commit"   => change.commit,
              "versions" => after.values.filter_map do |build|
                next unless (version = build.version)

                build.revision.positive? ? "#{version}_#{build.revision}" : version
              end.uniq,
            }
          end
          offset += BATCH_SIZE
        end
        { "revision" => @revision, **feeds }
      end

      sig { params(path: String, blob: String, sources: T::Hash[String, String]).returns(Builds) }
      def builds(path, blob, sources)
        @builds[[path, blob]] ||= @history.builds(path, sources.fetch(blob)).tap do |builds|
          if builds.values.any?(&:error)
            raise "Cannot read formula metadata for #{path} at #{blob}"
          end
        end
      end

      sig { params(offset: Integer).returns(T.nilable(T::Array[Change])) }
      def changes(offset)
        output = @history.git("log", @revision, "--first-parent", "--raw", "--root", "--no-abbrev",
                              "--diff-merges=first-parent", "--find-renames=50%",
                              "--max-count=#{BATCH_SIZE}", "--skip=#{offset}",
                              "--format=%x00commit%x00%H%x00%ct", "-z")
        return if output.empty?

        tokens = output.split("\0")
        result = T.let([], T::Array[Change])
        deleted = T.let({}, T::Hash[[String, String], [String, String]])
        commit = T.let("", String)
        timestamp = 0
        while (token = tokens.shift)
          if token == "commit"
            commit = tokens.shift || raise("Missing commit")
            timestamp = Integer(tokens.shift || raise("Missing commit date"), 10)
          elsif token.lstrip.start_with?(":")
            metadata = token.lstrip.delete_prefix(":").split
            old_mode = metadata.fetch(0)
            mode = metadata.fetch(1)
            before = metadata.fetch(2)
            after = metadata.fetch(3)
            status = metadata.fetch(4)
            old_path = tokens.shift || raise("Missing formula path")
            path = status.start_with?("R", "C") ? (tokens.shift || raise("Missing renamed formula path")) : old_path
            if status == "D" && %w[100644 100755].include?(old_mode) && @history.formula_path?(old_path)
              deleted[[commit, File.basename(old_path)]] = [old_path, before]
            end
            next if %w[100644 100755].exclude?(mode) || !@history.formula_path?(path)

            added = %w[100644 100755].exclude?(old_mode) || !@history.formula_path?(old_path)
            result << Change.new(commit:, timestamp:, path:, old_path:, before: added ? nil : before, after:, added:)
          end
        end
        result.each do |change|
          next unless change.added
          next unless (previous = deleted[[change.commit, File.basename(change.path)]])

          change.old_path, change.before = previous
          change.added = false
        end
        result
      end
    end
  end
end
