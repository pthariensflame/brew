# typed: true
# frozen_string_literal: true

require "formula_installer"
require "test/support/fixtures/testball"

RSpec.describe FormulaInstaller do
  include FileUtils

  describe "#fresh_install" do
    subject(:formula_installer) { described_class.new(Testball.new) }

    it "is true by default" do
      formula = Testball.new
      expect(formula_installer.fresh_install?(formula)).to be true
    end

    it "is false in developer mode" do
      formula = Testball.new
      allow(Homebrew::EnvConfig).to receive_messages(developer?: true)
      expect(formula_installer.fresh_install?(formula)).to be false
    end
  end

  describe "#fix_dynamic_linkage?" do
    subject(:formula_installer) { described_class.new(Testball.new) }

    it "is false for kegs without absolute symlinks" do
      keg = instance_double(Keg, absolute_symlinks?: false)
      expect(formula_installer.fix_dynamic_linkage?(keg)).to be false
    end

    it "is true for kegs with absolute symlinks" do
      keg = instance_double(Keg, absolute_symlinks?: true)
      expect(formula_installer.fix_dynamic_linkage?(keg)).to be true
    end
  end
end
