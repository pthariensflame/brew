# typed: true
# frozen_string_literal: true

require_relative "shared_examples"

RSpec.describe UnpackStrategy::P7Zip do
  subject(:path) { TEST_FIXTURE_DIR/"cask/container.7z" }

  include_examples "UnpackStrategy::detect"

  it "disables wildcard matching for archive names" do
    archive = mktmpdir/"archive?.7z"
    unpack_dir = mktmpdir
    strategy = described_class.new(archive)

    expect(strategy).to receive(:system_command!)
      .with("7zr", args: ["x", "-y", "-bd", "-bso0", "-spd", archive, "-o#{unpack_dir}"],
                   env: anything, verbose: false)

    strategy.extract(to: unpack_dir)
  end
end
