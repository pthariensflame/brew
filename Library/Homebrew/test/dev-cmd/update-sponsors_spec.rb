# typed: strict
# frozen_string_literal: true

require "cmd/shared_examples/args_parse"
require "dev-cmd/update-sponsors"

RSpec.describe Homebrew::DevCmd::UpdateSponsors do
  it_behaves_like "parseable arguments"

  test_each([
    { monthly_amount: 99, named_types: [], logo: false },
    { monthly_amount: 100, named_types: ["User"], logo: false },
    { monthly_amount: 249, named_types: ["User"], logo: false },
    { monthly_amount: 250, named_types: %w[User Organization], logo: false },
    { monthly_amount: 1000, named_types: %w[User Organization], logo: false },
    { monthly_amount: 1499, named_types: %w[User Organization], logo: false },
    { monthly_amount: 1500, named_types: %w[User Organization], logo: true },
    { monthly_amount: 1750, named_types: %w[User Organization], logo: true },
  ].product(%w[User Organization], [0, 50])) do |sponsorship, type, price_increase|
    it "uses API tier floors for #{type} accounts at $#{sponsorship[:monthly_amount]} plus $#{price_increase}" do
      readme = mktmpdir/"README.md"
      stub_const("HOMEBREW_REPOSITORY", readme.dirname)
      readme.write "Homebrew is generously supported by [Old sponsor](https://github.com/old).\n" \
                   "\n[![Old sponsor](https://github.com/old.png?size=64)](https://github.com/old)\n"
      command = described_class.new([])
      allow(command).to receive(:system_command).and_return(
        instance_double(SystemCommand::Result, status: instance_double(Process::Status, success?: false)),
      )
      allow(command).to receive(:puts)
      allow(GitHub).to receive(:sponsorship_tiers).with("Homebrew").and_return([
        { monthly_amount: 1, description: "You get a warm fuzzy feeling for supporting the project." },
        {
          monthly_amount: 100 + price_increase,
          description:    "We will note your user's name in plain-text in our README " \
                          "(individuals only, no organisations).",
        },
        {
          monthly_amount: 250 + price_increase,
          description:    "We will note your organisation's or user's name in plain-text in our README.",
        },
        {
          monthly_amount: 1500 + price_increase,
          description:    "We will put your name and linked organisation's logo in our README.",
        },
      ])
      allow(GitHub).to receive(:sponsorships).with("Homebrew").and_return([{
        type:,
        monthly_amount: sponsorship[:monthly_amount] + price_increase,
        name:           "Sponsor",
        login:          "sponsor",
      }])

      command.run

      expected = "Homebrew is generously supported by "
      expected += "Sponsor and " if sponsorship[:named_types].include?(type)
      expected += "many other users and organisations via [GitHub Sponsors](https://github.com/sponsors/Homebrew).\n"
      if sponsorship[:logo]
        expected += "\n[![Sponsor](https://github.com/sponsor.png?size=64)](https://github.com/sponsor)\n"
      end
      expect(readme.read).to eq(expected)
    end
  end
end
