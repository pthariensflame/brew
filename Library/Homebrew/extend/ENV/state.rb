# typed: strict
# frozen_string_literal: true

require "formula"

module SharedEnvExtension
  # Build metadata cannot be stored on Ruby's shareable ENV object.
  class State < T::Struct
    prop :formula, T.nilable(Formula)
    prop :cc, T.nilable(String)
    prop :build_bottle, T.nilable(T::Boolean)
    prop :bottle_arch, T.nilable(String)
    prop :debug_symbols, T.nilable(T::Boolean)
    prop :testing_formula, T::Boolean, default: false
    prop :compiler, T.nilable(T.any(Symbol, String))
    prop :fortran_setup_done, T::Boolean, default: false
    prop :keg_only_deps, T::Array[Formula], default: []
    prop :deps, T::Array[Formula], default: []
    prop :run_time_deps, T::Array[Formula], default: []

    sig { returns(State) }
    def self.process
      @process ||= T.let(new, T.nilable(State))
    end
  end
end
