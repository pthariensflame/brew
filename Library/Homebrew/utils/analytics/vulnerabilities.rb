# typed: strict
# frozen_string_literal: true

require "vulns/vulnerability"
require "utils/analytics"

module Utils
  module Analytics
    # Summaries of the advisory corpus and the existing formula API findings.
    module Vulnerabilities
      sig { params(repository: Pathname).returns(T::Hash[String, T.anything]) }
      def self.corpus(repository)
        counts = Hash.new(0)
        severity = Hash.new(0)
        formulae = Set.new
        upstream = Set.new
        (repository/"advisories").glob("*.json").each do |path|
          record = JSON.parse(path.read)
          counts["records"] += 1
          if record["withdrawn"].present?
            counts["withdrawn"] += 1
            next
          end
          vulnerability = Homebrew::Vulns::Vulnerability.new(record)
          vulnerability.upstream.each { |identifier| upstream << identifier }
          severity[vulnerability.severity&.to_s || "unknown"] += 1
          vulnerability.affected.each do |affected|
            formulae << affected.dig("package", "name")
          end
          ecosystem = vulnerability.affected.first&.fetch("ecosystem_specific", {}) || {}
          category = if record.dig("database_specific", "source") == "matched" && ecosystem["range_state"].nil?
            "uncomparable"
          elsif ecosystem["fix"] == "patch"
            "patch"
          elsif ecosystem["fix"] == "bump"
            "bump"
          else
            "unresolved"
          end
          counts[category] += 1
        end
        {
          "generated_at" => Time.now.utc.iso8601,
          "source"       => "https://github.com/Homebrew/advisory-database",
          "revision"     => if (repository/".git").exist?
                              Utils.safe_popen_read("git", "-C", repository.to_s, "rev-parse", "HEAD").strip
          end,
          "counts"       => counts.merge("formulae" => formulae.size, "upstream_identifiers" => upstream.size),
          "severity"     => severity,
        }
      end

      sig {
        params(formulae: T::Hash[String, T::Hash[String, T.anything]], available: T::Boolean,
               revision: T.nilable(String)).returns(T::Hash[String, T.anything])
      }
      def self.catalogue(formulae, available:, revision:)
        counts = Hash.new(0)
        severity = Hash.new(0)
        upstream = Set.new
        rows = formulae.filter_map do |name, formula|
          findings = formula["vulnerabilities"]
          case findings
          when Hash then nil
          else next
          end

          open = findings.fetch("open")
          patched = findings.fetch("patched")
          fixed = findings.fetch("fixed_count")
          counts["covered_formulae"] += 1
          counts["formulae_with_open_findings"] += 1 if open.any?
          counts["open"] += open.length
          counts["patched"] += patched.length
          counts["fixed"] += fixed
          open.each do |entry|
            severity[entry["severity"] || "unknown"] += 1
            Array(entry["upstream"]).each { |identifier| upstream << identifier }
          end
          versions = case (value = formula["versions"])
          when Hash then value
          else {}
          end
          {
            "formula"  => name,
            "version"  => versions["stable"],
            "revision" => formula["revision"],
            "open"     => open.length,
            "patched"  => patched.length,
            "fixed"    => fixed,
            "critical" => open.count { |entry| entry["severity"] == "critical" },
            "high"     => open.count { |entry| entry["severity"] == "high" },
          }
        end
        {
          "generated_at" => Time.now.utc.iso8601,
          "source"       => "https://formulae.brew.sh/api/advisories.json",
          "revision"     => revision,
          "available"    => available,
          "counts"       => counts.merge("catalogue_formulae"        => formulae.size,
                                         "uncovered_formulae"        => formulae.size - counts["covered_formulae"],
                                         "open_upstream_identifiers" => upstream.size),
          "severity"     => severity,
          "formulae"     => rows.sort_by { |row| [-row.fetch("open"), row.fetch("formula")] },
        }
      end
    end
  end
end
