# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "utils/analytics/formula_feeds"

module Homebrew
  module DevCmd
    class GenerateFormulaFeeds < AbstractCommand
      cmd_args do
        description <<~EOS
          Generate recent formula additions and updates for <#{HOMEBREW_API_WWW}> feeds.
          Requires a complete `homebrew/core` Git history.
        EOS
        flag "--repository=", description: "Read formula history from this Git repository instead of `homebrew/core`."
        flag "--revision=", description: "Read history ending at this revision instead of `HEAD`."
        flag "--output=", description: "Write JSON to this path instead of `_data/formula_feeds.json`."
        flag "--new-limit=", description: "Maximum number of new formula entries (default: 50). Use 0 for none."
        flag "--updated-limit=",
             description: "Maximum number of updated formula entries (default: 500). Use 0 for none."

        named_args :none
        hide_from_man_page!
      end

      sig { override.void }
      def run
        limits = { "new" => args.new_limit, "updated" => args.updated_limit }.to_h do |feed, value|
          value ||= Utils::Analytics::FormulaFeeds::LIMITS.fetch(feed).to_s
          unless value.match?(/\A\d+\z/)
            raise UsageError, "`--#{feed}-limit` must be a non-negative integer."
          end

          [feed, value.to_i]
        end
        feeds = Utils::Analytics::FormulaFeeds.new(
          Pathname(args.repository || CoreTap.instance.path), revision: args.revision || "HEAD", limits:
        ).generate
        output = Pathname(args.output || "_data/formula_feeds.json")
        output.dirname.mkpath
        output.atomic_write("#{JSON.pretty_generate(feeds)}\n")
        puts "Generated #{feeds.fetch("new").length} new and #{feeds.fetch("updated").length} updated formula entries"
      end
    end
  end
end
