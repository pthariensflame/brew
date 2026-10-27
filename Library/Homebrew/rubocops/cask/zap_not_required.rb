# typed: strict
# frozen_string_literal: true

module RuboCop
  module Cop
    module Cask
      # This cop replaces the `# No zap stanza required` comment with the
      # auditable `zap :not_required` stanza.
      #
      # Example
      #   # bad
      #   # No zap stanza required
      #
      #   # good
      #   zap :not_required
      class ZapNotRequired < Base
        include CaskHelp
        extend AutoCorrector

        MSG = "Use `zap :not_required` instead of a `# No zap stanza required` comment."

        sig { override.params(cask_block: RuboCop::Cask::AST::CaskBlock).void }
        def on_cask(cask_block)
          cask_block.comments.each do |comment|
            next unless comment.text.match?(/\A#\s*no zap stanza required\.?\z/i)
            next unless comment_line?(processed_source[comment.loc.line - 1])

            add_offense(comment) do |corrector|
              corrector.replace(comment, "zap :not_required")
            end
          end
        end
      end
    end
  end
end
