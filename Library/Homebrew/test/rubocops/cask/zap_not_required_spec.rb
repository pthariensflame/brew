# typed: strict
# frozen_string_literal: true

require "rubocops/rubocop-cask"

RSpec.describe RuboCop::Cop::Cask::ZapNotRequired, :config do
  it "flags and autocorrects a `# No zap stanza required` comment" do
    expect_offense <<~CASK
      cask "foo" do
        app "Foo.app"

        # No zap stanza required
        ^^^^^^^^^^^^^^^^^^^^^^^^ Use `zap :not_required` instead of a `# No zap stanza required` comment.
      end
    CASK

    expect_correction <<~CASK
      cask "foo" do
        app "Foo.app"

        zap :not_required
      end
    CASK
  end

  it "ignores comments that explain more" do
    expect_no_offenses <<~CASK
      cask "foo" do
        app "Foo.app"

        # No zap stanza required as the app stores no user data
      end
    CASK
  end

  it "ignores comments that follow code" do
    expect_no_offenses <<~CASK
      cask "foo" do
        app "Foo.app" # No zap stanza required
      end
    CASK
  end
end
