# typed: strict
# frozen_string_literal: true

module Utils
  # Invalidate selection when an executable fails its version check.
  module Tool
    sig { params(tool: Symbol).void }
    def self.invalidate_cache(tool)
      return unless [:git, :curl, :svn].include?(tool)

      # Keep the cache location in sync with install_tool in utils/tool.sh.
      (HOMEBREW_CACHE/"tool-selection"/tool.to_s).unlink
    rescue SystemCallError
      # Cache access must not replace the original error.
      nil
    end
  end
end
