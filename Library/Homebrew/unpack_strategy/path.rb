# typed: strict
# frozen_string_literal: true

require "system_command"

module UnpackStrategy
  # A source path with cached metadata shared by archive detection strategies.
  # @api private
  class Path < Pathname
    include SystemCommand::Mixin

    sig { params(path: T.any(String, Pathname)).void }
    def initialize(path)
      super
      @magic_number = T.let(nil, T.nilable(String))
      @file_type = T.let(nil, T.nilable(String))
      @zipinfo = T.let(nil, T.nilable(T::Array[String]))
    end

    sig { returns(String) }
    def magic_number
      @magic_number ||= if directory?
        ""
      else
        # Length of the longest regex (currently Tar).
        binread(262) || ""
      end
    end

    sig { returns(String) }
    def file_type
      @file_type ||= system_command("file", args: ["-b", self], print_stderr: false).stdout.chomp
    end

    sig { returns(T::Array[String]) }
    def zipinfo
      @zipinfo ||= with_literal_name do |archive|
        system_command("zipinfo", args: ["-1", archive], print_stderr: false)
          .stdout
          .encode(Encoding::UTF_8, invalid: :replace)
          .split("\n")
      end
    end

    # Yield an isolated, fixed-name link for tools that interpret archive filenames.
    sig {
      type_parameters(:U)
        .params(temporary_directory: Pathname, _block: T.proc.params(archive: Pathname).returns(T.type_parameter(:U)))
        .returns(T.type_parameter(:U))
    }
    def with_literal_name(temporary_directory: HOMEBREW_TEMP, &_block)
      Dir.mktmpdir("homebrew-unpack", temporary_directory.to_s) do |tmpdir|
        archive = Pathname(tmpdir)/"archive"
        FileUtils.ln_s expand_path, archive
        yield archive
      end
    rescue ErrorDuringExecution => e
      raise e.exception("Could not process archive #{self}:\n#{e.message}"), cause: nil
    end
  end
end
