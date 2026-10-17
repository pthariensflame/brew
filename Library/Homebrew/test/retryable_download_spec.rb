# typed: true
# frozen_string_literal: true

require "retryable_download"

RSpec.describe Homebrew::RetryableDownload do
  subject(:download) { described_class.new(resource, tries: 3) }

  let(:resource) do
    Resource.new("foo").tap do |resource|
      resource.url("https://example.com/foo.tar.gz")
    end
  end

  it "does not retry a local write failure" do
    allow(resource.downloader).to receive(:curl_headers).and_return({ responses: [] })
    expect(resource.downloader).to receive(:curl).once
                                                 .and_raise(ErrorDuringExecution.new(["curl"], status: 23))

    expect { download.fetch(quiet: true) }.to raise_error(DownloadWriteError)
  end
end
