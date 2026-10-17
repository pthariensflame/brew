# typed: strict
# frozen_string_literal: true

require "semver"
require "vulns/cvss"
require "vulns/vulnerability"
require "vulns/osv"
require "vulns/scanner"
require "vulns/output"

module Homebrew
  # Checks formulae for known security vulnerabilities via OSV.dev.
  # See {Homebrew::Cmd::Vulns} for the user-facing command.
  module Vulns
    SEVERITIES = %w[low medium high critical].freeze

    sig { params(severity: T.nilable(String)).returns(T.nilable(Symbol)) }
    def self.min_severity(severity)
      return if severity.nil?

      severity = severity.downcase
      raise UsageError, "`--severity` must be one of: #{SEVERITIES.join(", ")}" unless SEVERITIES.include?(severity)

      severity.to_sym
    end

    # Select upgrade candidates using the same installed-source evidence as `brew vulns`.
    sig { params(formulae: T::Array[Formula], severity: T.nilable(String)).returns(T::Array[Formula]) }
    def self.select_vulnerable(formulae, severity: nil)
      results = Scanner.new(formulae, min_severity: min_severity(severity)).scan
      incomplete = results.skipped_formulae | results.outdated_without_sbom
      if incomplete.present?
        raise "Incomplete vulnerability scan for: #{incomplete.sort.join(", ")}.\n" \
              "Run `brew vulns --list-skipped` and review installed-source evidence before upgrading."
      end

      vulnerable = results.findings.select { |finding| finding.open.any? }.map(&:name)
      formulae.select { |formula| vulnerable.include?(formula.full_name) }
    end
  end
end
