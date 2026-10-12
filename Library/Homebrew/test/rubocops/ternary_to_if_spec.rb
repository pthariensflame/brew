# typed: strict
# frozen_string_literal: true

require "rubocops/ternary_to_if"

RSpec.describe RuboCop::Cop::Homebrew::TernaryToIf, :config do
  it "corrects a local assignment with a nil fallback" do
    expect_offense(<<~RUBY)
      source = reuse_platforms ? @sources[key] : nil
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use modifier `if` instead of a ternary with a `nil` fallback.
    RUBY

    expect_correction(<<~RUBY)
      source = @sources[key] if reuse_platforms
    RUBY
  end

  it "does not change an existing local variable" do
    expect_no_offenses(<<~RUBY)
      source = previous_source
      source = reuse_platforms ? @sources[key] : nil
    RUBY
  end

  it "does not change a method parameter" do
    expect_no_offenses(<<~RUBY)
      def lookup(source)
        source = reuse_platforms ? @sources[key] : nil
      end
    RUBY
  end

  it "does not change a block parameter" do
    expect_no_offenses(<<~RUBY)
      sources.each do |source|
        source = reuse_platforms ? @sources[key] : nil
      end
    RUBY
  end

  it "does not change a captured local variable" do
    expect_no_offenses(<<~RUBY)
      source = previous_source
      keys.each do |key|
        source = reuse_platforms ? @sources[key] : nil
      end
    RUBY
  end

  it "does not change assignments inside loops" do
    expect_no_offenses(<<~RUBY)
      while next_key?
        source = reuse_platforms ? @sources[key] : nil
      end
    RUBY
  end

  it "does not change assignments that can be retried" do
    expect_no_offenses(<<~RUBY)
      begin
        source = reuse_platforms ? @sources[key] : nil
      rescue
        retry
      end
    RUBY
  end

  it "does not move variable declarations after their references" do
    expect_no_offenses(<<~RUBY)
      source = (key = next_key) ? @sources[key] : nil
    RUBY
  end

  it "does not change assignments within expressions" do
    expect_no_offenses(<<~RUBY)
      consume(source = reuse_platforms ? @sources[key] : nil)
    RUBY
  end

  it "does not change endless method definitions" do
    allow(self).to receive(:ruby_version).and_return(4.0)

    expect_no_offenses(<<~RUBY)
      def lookup = source = reuse_platforms ? @sources[key] : nil
    RUBY
  end

  it "preserves multiline ternaries and their comments" do
    expect_no_offenses(<<~RUBY)
      source = reuse_platforms ? # Reuse cached platforms.
        @sources[key] : nil
    RUBY
  end

  it "does not change other assignment targets" do
    expect_no_offenses(<<~RUBY)
      @source = reuse_platforms ? @sources[key] : nil
      @@source = reuse_platforms ? @sources[key] : nil
      $source = reuse_platforms ? @sources[key] : nil
      SOURCE = reuse_platforms ? @sources[key] : nil
      cache.source = reuse_platforms ? @sources[key] : nil
    RUBY
  end

  it "does not change other conditionals" do
    expect_no_offenses(<<~RUBY)
      fallback = reuse_platforms ? @sources[key] : false
      source = if reuse_platforms
        @sources[key]
      end
      modifier = @sources[key] if reuse_platforms
    RUBY
  end

  it "does not move variable declarations before method calls" do
    expect_no_offenses(<<~RUBY)
      source = reuse_platforms ? (reuse_platforms = true) : nil
    RUBY
  end

  it "does not change assignments that can be redone" do
    expect_no_offenses(<<~RUBY)
      keys.each do |key|
        source = reuse_platforms ? @sources[key] : nil
        redo if retry_source?
      end
    RUBY
  end

  it "corrects fresh locals in methods and blocks" do
    expect_offense(<<~RUBY)
      def lookup(reuse_platforms, key)
        source = reuse_platforms ? @sources[key] : nil
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use modifier `if` instead of a ternary with a `nil` fallback.
      end
      keys.each do |key|
        source = reuse_platforms ? @sources[key] : nil
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use modifier `if` instead of a ternary with a `nil` fallback.
      end
    RUBY

    expect_correction(<<~RUBY)
      def lookup(reuse_platforms, key)
        source = @sources[key] if reuse_platforms
      end
      keys.each do |key|
        source = @sources[key] if reuse_platforms
      end
    RUBY
  end

  it "preserves compound conditions and trailing comments" do
    expect_offense(<<~RUBY)
      source = use_platforms && ready? ? @sources[key] : nil # Reuse cached platforms.
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use modifier `if` instead of a ternary with a `nil` fallback.
    RUBY

    expect_correction(<<~RUBY)
      source = @sources[key] if use_platforms && ready? # Reuse cached platforms.
    RUBY
  end

  it "corrects a local assignment with a nil true branch" do
    expect_offense(<<~RUBY)
      source = skip_platforms ? nil : @sources[key] # Keep this comment.
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use modifier `unless` instead of a ternary with a `nil` fallback.
    RUBY

    expect_correction(<<~RUBY)
      source = @sources[key] unless skip_platforms # Keep this comment.
    RUBY
  end

  it "corrects a false value with a nil true branch" do
    expect_offense(<<~RUBY)
      source = skip_platforms ? nil : false
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use modifier `unless` instead of a ternary with a `nil` fallback.
    RUBY

    expect_correction(<<~RUBY)
      source = false unless skip_platforms
    RUBY
  end

  it "does not change an existing local with a nil true branch" do
    expect_no_offenses(<<~RUBY)
      source = previous_source
      source = skip_platforms ? nil : @sources[key]
    RUBY
  end

  it "does not change a nil true branch inside a loop" do
    expect_no_offenses(<<~RUBY)
      while next_key?
        source = skip_platforms ? nil : @sources[key]
      end
    RUBY
  end

  it "does not move variable declarations in a nil true branch conditional" do
    expect_no_offenses(<<~RUBY)
      source = (key = next_key) ? nil : @sources[key]
    RUBY
  end

  test_each(["&&", "||"]) do |operator|
    it "does not introduce an unless condition with #{operator}" do
      expect_no_offenses(<<~RUBY)
        source = skip_platforms #{operator} ready? ? nil : @sources[key]
      RUBY
    end
  end
end
