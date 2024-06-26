# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for dynamic methods in `Homebrew::DevCmd::Extract`.
# Please instead update this file by running `bin/tapioca dsl Homebrew::DevCmd::Extract`.

class Homebrew::DevCmd::Extract
  sig { returns(Homebrew::DevCmd::Extract::Args) }
  def args; end
end

class Homebrew::DevCmd::Extract::Args < Homebrew::CLI::Args
  sig { returns(T::Boolean) }
  def f?; end

  sig { returns(T::Boolean) }
  def force?; end

  sig { returns(T.nilable(String)) }
  def version; end
end
