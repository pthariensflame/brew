# typed: strict
# frozen_string_literal: true

require "cask/artifact/abstract_uninstall"

module Cask
  module Artifact
    # Artifact corresponding to the `zap` stanza.
    class Zap < AbstractUninstall
      # `:not_required` is serialised as an empty stanza, which older versions of
      # Homebrew can still load from the API.
      sig { params(cask: Cask, exemption: T.nilable(Symbol), directives: DirectivesType).returns(Zap) }
      def self.from_args(cask, exemption = nil, **directives)
        if exemption && (exemption != :not_required || directives.any?)
          raise CaskInvalidError.new(cask, "'zap' stanza requires either directives or only ':not_required'.")
        end

        new(cask, **directives)
      end

      # Removing files also waits, as `uninstall` steps may still need them, e.g. to
      # identify a keychain certificate to delete.
      sig { override.returns(T::Array[Symbol]) }
      def deferred_directives = [:pkgutil, :delete, :trash, :rmdir]
    end
  end
end
