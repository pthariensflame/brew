# typed: false

cask "with-appimage" do
  version "1.2.3"
  sha256 "27786c7a58d945c16dde16e7316465931cbaf406d0e0db25bac8ce74c556015d"

  url "file://#{TEST_FIXTURE_DIR}/cask/naked.AppImage"
  name "With AppImage"
  desc "Cask with an app_image stanza"
  homepage "https://brew.sh/with-appimage"

  depends_on :linux

  app_image "naked.AppImage"
end
