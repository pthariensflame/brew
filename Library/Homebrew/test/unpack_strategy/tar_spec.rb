# typed: true
# frozen_string_literal: true

require_relative "shared_examples"

RSpec.describe UnpackStrategy::Tar do
  subject(:path) { TEST_FIXTURE_DIR/"cask/container.tar.gz" }

  include_examples "UnpackStrategy::detect"
  include_examples "#extract", children: ["container"]

  describe "#extract failures" do
    subject(:strategy) { described_class.new(path) }

    let(:unpack_dir) { mktmpdir/"unpacked" }
    let(:disk_space_error) do
      ErrorDuringExecution.new(["tar"], status: 2,
                                        output: [[:stderr, "payload: Write failed: No space left on device\n"]])
    end

    it "reports the archive and destination when tar runs out of disk space" do
      allow(strategy).to receive(:system_command!).and_raise(disk_space_error)

      expect { strategy.extract(to: unpack_dir) }.to raise_error(ExtractionDiskSpaceError, <<~EOS)
        Not enough disk space to extract:
          #{path}
        Free up space on the filesystems containing these directories:
          #{unpack_dir}
          #{strategy.temporary_directory}
        Then try again.
      EOS
    end

    it "preserves tar's original failure as the cause" do
      allow(strategy).to receive(:system_command!).and_raise(disk_space_error)

      expect { strategy.extract(to: unpack_dir) }.to raise_error(ExtractionDiskSpaceError) { |error|
        expect(error.cause).to equal(disk_space_error)
      }
    end

    it "handles an out-of-space failure returned by the extraction sandbox" do
      allow(Sandbox).to receive(:isolate_operation?).and_return(true)
      allow(Sandbox).to receive(:operation).and_raise(disk_space_error)

      expect { strategy.extract(to: unpack_dir) }.to raise_error(ExtractionDiskSpaceError)
    end

    it "handles a native out-of-space error" do
      allow(strategy).to receive(:system_command!).and_raise(Errno::ENOSPC)

      expect { strategy.extract(to: unpack_dir) }.to raise_error(ExtractionDiskSpaceError)
    end

    it "does not misreport a corrupt archive as insufficient disk space" do
      error = ErrorDuringExecution.new(["tar"], status: 2,
                                                output: [[:stderr, "tar: Unrecognized archive format\n"]])
      allow(strategy).to receive(:system_command!).and_raise(error)

      expect { strategy.extract(to: unpack_dir) }.to raise_error { |raised|
        expect(raised).to equal(error)
      }
    end

    it "uses a UTF-8 locale for tar so non-ASCII paths can be extracted" do
      expect(strategy).to receive(:system_command!).with("tar", hash_including(env: { "LC_ALL" => "en_US.UTF-8" }))

      strategy.extract(to: unpack_dir)
    end
  end

  it "keeps decompression intermediates in the configured temporary directory" do
    temporary_directory = mktmpdir
    unpack_dir = mktmpdir
    strategy = described_class.new(TEST_FIXTURE_DIR/"tarballs/testball-0.1.tbz", temporary_directory:)
    allow(DependencyCollector).to receive(:tar_needs_bzip2_dependency?).and_return(true)
    temporary_parents = []
    allow(Dir).to receive(:mktmpdir).and_wrap_original do |original, *args, &block|
      temporary_parents << Pathname(args.fetch(1)) if args.first.to_s.start_with?("homebrew-tar")
      original.call(*args, &block)
    end

    strategy.extract(to: unpack_dir)

    expect([temporary_parents, (unpack_dir/"test-0.1/libexec/NOOP").file?, temporary_directory.children])
      .to eq([[temporary_directory], true, []])
  end

  context "when TAR archive is corrupted" do
    subject(:path) do
      (mktmpdir/"test.tar").tap do |path|
        FileUtils.touch path
      end
    end

    include_examples "UnpackStrategy::detect"
  end
end
