# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "utils/analytics/api"

module Homebrew
  module DevCmd
    class GenerateAnalyticsApi < AbstractCommand
      cmd_args do
        description <<~EOS
          Generates analytics API data files for <#{HOMEBREW_API_WWW}>.
          The generated files are written to the current directory.
        EOS
        switch "--influx",
               description: "Generate only InfluxDB analytics, without local Git histories or GitHub queries."
        switch "--repositories",
               description: "Generate only repository and catalogue analytics from local Git history and GitHub."
        switch "--formula-history",
               description: "Generate only formula version history, resuming its persistent Git checkpoint."
        switch "--releases",
               description: "Generate only brew release analytics from local Git history and tags."
        flag "--legacy-homebrew=",
             description: "Include the legacy Homebrew repository at this path in repository analytics."
        flag "--homebrew-site=",
             description: "Read brew.sh release announcements and security disclosures from this Git checkout."
        flag "--history=",
             description: "Reuse completed-year aggregates from this JSON file."
        switch "--github-packages",
               description: "Generate only package downloads, using existing 30-day install analytics."
        flag "--github-packages-limit=",
             description: "Fetch downloads for the top number of formulae by install analytics " \
                          "(1-1000; default: 1000)."

        named_args :none

        conflicts "--influx", "--repositories", "--formula-history", "--releases", "--github-packages"

        hide_from_man_page!
      end

      sig { override.void }
      def run
        generator = Utils::Analytics::API.new(history: args.history, homebrew_site: args.homebrew_site,
                                              legacy_homebrew: args.legacy_homebrew,
                                              github_packages_limit:)
        if args.influx?
          generator.generate_influx
        elsif args.repositories?
          generator.generate_repositories
        elsif args.formula_history?
          generator.generate_formula_history
        elsif args.releases?
          generator.generate_releases
        elsif args.github_packages?
          generator.generate_github_packages
        else
          generator.generate
        end
      end

      sig { returns(Integer) }
      def github_packages_limit
        limit = Integer(args.github_packages_limit || "1000", 10)
        raise ArgumentError unless (1..1000).cover?(limit)

        limit
      rescue ArgumentError
        raise UsageError, "--github-packages-limit must be between 1 and 1000"
      end
    end
  end
end
