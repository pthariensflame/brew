# typed: strict
# frozen_string_literal: true

require_relative "../standalone"
require "fiddle"

module Utils
  # Disclaim the parent's TCC responsibility for macOS sandbox workers where supported.
  module Disclaim
    POSIX_SPAWN_SETEXEC = 0x0040

    # Replaces this process, preserving its PID, environment and inherited descriptors.
    sig { params(args: T::Array[String]).void }
    def self.exec(args)
      args.each do |arg|
        raise ArgumentError, "Argument contains null byte" if arg.include?("\0")
      end

      # Private libSystem API, also used by LLDB and Chromium.
      disclaim = begin
        Fiddle::Function.new(Fiddle::Handle::DEFAULT["responsibility_spawnattrs_setdisclaim"],
                             [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT], Fiddle::TYPE_INT)
      rescue Fiddle::DLError
        nil
      end
      return exec_without_disclaim(args) if disclaim.nil?

      functions = {
        "posix_spawnattr_init"     => [Fiddle::TYPE_VOIDP],
        "posix_spawnattr_setflags" => [Fiddle::TYPE_VOIDP, Fiddle::TYPE_SHORT],
        "posix_spawn"              => [Fiddle::TYPE_VOIDP] * 6,
        "posix_spawnattr_destroy"  => [Fiddle::TYPE_VOIDP],
      }.to_h do |name, types|
        [name, Fiddle::Function.new(Fiddle::Handle::DEFAULT[name], types, Fiddle::TYPE_INT)]
      end

      attributes = "\0" * Fiddle::SIZEOF_VOIDP
      error = functions.fetch("posix_spawnattr_init").call(attributes)
      raise SystemCallError.new("posix_spawnattr_init", error) unless error.zero?

      begin
        # POSIX_SPAWN_SETEXEC preserves Homebrew's signal and timeout handling.
        error = functions.fetch("posix_spawnattr_setflags").call(attributes, POSIX_SPAWN_SETEXEC)
        raise SystemCallError.new("posix_spawnattr_setflags", error) unless error.zero?

        return exec_without_disclaim(args) unless disclaim.call(attributes, 1).zero?

        error = functions.fetch("posix_spawn").call(
          nil, args.fetch(0), nil, attributes,
          [*args, nil].pack("p*"), [*ENV.map { |key, value| "#{key}=#{value}" }, nil].pack("p*")
        )
        # POSIX_SPAWN_SETEXEC means posix_spawn only returns on failure.
        raise SystemCallError.new("posix_spawn", error)
      ensure
        functions.fetch("posix_spawnattr_destroy").call(attributes)
      end
    end

    sig { params(args: T::Array[String]).void }
    def self.exec_without_disclaim(args)
      warn "Warning: macOS privacy permission isolation is unavailable.\n" \
           "Continuing with the existing sandbox restrictions."
      Kernel.exec([args.fetch(0), args.fetch(0)], *args.drop(1))
    end
    private_class_method :exec_without_disclaim
  end
end

Utils::Disclaim.exec(ARGV) if $PROGRAM_NAME == __FILE__
