# typed: strict
# frozen_string_literal: true

module OS
  module Linux
    module FormulaInstaller
      extend T::Helpers

      requires_ancestor { ::FormulaInstaller }

      sig { params(formula: Formula).returns(T::Boolean) }
      def fresh_install?(formula)
        !Homebrew::EnvConfig.developer? &&
          !formula.any_version_installed?
      end

      # Fixing dynamic linkage on Linux only relativises absolute symlinks, so
      # skip starting a sandboxed worker for kegs without any.
      sig { params(keg: ::Keg).returns(T::Boolean) }
      def fix_dynamic_linkage?(keg) = keg.absolute_symlinks?
    end
  end
end

FormulaInstaller.prepend(OS::Linux::FormulaInstaller)
