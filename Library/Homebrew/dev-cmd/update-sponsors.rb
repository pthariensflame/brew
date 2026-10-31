# typed: strict
# frozen_string_literal: true

require "utils/text"

require "abstract_command"
require "utils/github"
require "system_command"

module Homebrew
  module DevCmd
    class UpdateSponsors < AbstractCommand
      include SystemCommand::Mixin

      cmd_args do
        description <<~EOS
          Update the list of GitHub Sponsors in the `Homebrew/brew` README.
        EOS

        named_args :none

        hide_from_man_page!
      end

      sig { override.void }
      def run
        tiers = GitHub.sponsorship_tiers("Homebrew")
        odie "No sponsorship tiers found!" if tiers.empty?

        sponsorships = GitHub.sponsorships("Homebrew")
        unless sponsorships.any? { |s| s[:monthly_amount].positive? }
          odie "No sponsorship amounts found! Ensure you have sufficient permissions!"
        end

        named_sponsors = []
        logo_sponsors = []

        sponsorships.each do |s|
          applicable_tiers = tiers.select do |tier|
            next false if s[:monthly_amount] < tier[:monthly_amount]

            description = tier[:description]
            description.match?(/\bREADME\b/i) &&
              (s[:type] != "Organization" || !description.match?(/\bindividuals only\b/i))
          end
          next if applicable_tiers.empty?

          named_sponsors << s[:name]

          next unless applicable_tiers.any? { |tier| tier[:description].match?(/\blogo\b/i) }

          logo_sponsors << "[![#{s[:name]}](https://github.com/#{s[:login]}.png?size=64)](https://github.com/#{s[:login]})"
        end

        named_sponsors << "many other users and organisations via [GitHub Sponsors](https://github.com/sponsors/Homebrew)"

        readme = HOMEBREW_REPOSITORY/"README.md"
        content = readme.read
        content.gsub!(/(Homebrew is generously supported by) .*\Z/m,
                      "\\1 #{Utils::Text.to_sentence(named_sponsors)}.\n")
        content << "\n#{logo_sponsors.join}\n" if logo_sponsors.presence

        File.write(readme, content)

        diff = system_command "git", args: [
          "-C", HOMEBREW_REPOSITORY, "diff", "--exit-code", "README.md"
        ]
        if diff.status.success?
          ofail "No changes to list of sponsors."
        else
          puts "List of sponsors updated in the README."
        end
      end
    end
  end
end
