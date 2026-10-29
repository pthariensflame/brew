# typed: strict
# frozen_string_literal: true

# Run the command printed by `brew doctor`, which selects Homebrew's Ruby and sudo.
# This script does not load brew or download dependencies while running as root.
require "fileutils"
require "openssl"
require "tempfile"

abort "Error: This script only supports macOS." unless RUBY_PLATFORM.include?("darwin")
abort "Error: Run this script with sudo." unless Process.euid.zero?

cert_file = "/etc/ssl/cert.pem"
backup_file = "#{cert_file}.bak"
original_backup_file = "#{cert_file}.orig"

begin
  contents = File.read(cert_file)
  # Certificate.load skips trusted PEM entries, so rewriting would silently drop them.
  if contents.include?("-----BEGIN TRUSTED CERTIFICATE-----")
    abort "Error: Refusing to change a bundle containing TRUSTED CERTIFICATE entries."
  end

  certificates = OpenSSL::X509::Certificate.load(contents)
  # Keep root names in sync with check_for_emudhra_certificates in extend/os/mac/diagnostic.rb.
  remaining = certificates.reject do |certificate|
    certificate.subject.to_a.any? do |name, value, _type|
      name == "CN" && ["emSign ECC Root CA - G3", "AAA Certificate Services"].include?(value)
    end
  end
  abort "Error: Refusing to install an empty certificate bundle." if remaining.empty?

  if remaining.length == certificates.length
    puts "The roots are already absent. Run `brew doctor` to check your system."
    exit
  end

  puts "Removing these roots can break HTTPS connections to some websites."
  # Stage on the same filesystem so rename replaces the bundle atomically. A failed
  # write or backup leaves the original in place; Tempfile cleans up the staged copy.
  Tempfile.create(["cert", ".pem"], File.dirname(cert_file)) do |file|
    file.write(remaining.map(&:to_pem).join)
    file.flush
    file.chmod(0644)
    file.fsync
    # Publish only a complete, synced backup. Keep the first copy separately, and
    # refresh the restore point when a system update has replaced the bundle.
    Tempfile.create(["cert-backup", ".bak"], File.dirname(cert_file)) do |backup|
      FileUtils.cp(cert_file, backup.path, preserve: true)
      backup.fsync
      File.link(backup.path, original_backup_file) unless File.exist?(original_backup_file)
      File.rename(backup.path, backup_file)
    end
    File.open(File.dirname(cert_file), File::RDONLY, &:fsync)
    File.rename(file.path, cert_file)
    File.open(File.dirname(cert_file), File::RDONLY, &:fsync)
  end

  puts <<~EOS
    Removed roots that trust compromised eMudhra certificates.
    Backup: #{backup_file}
    To restore it:
      sudo cp -p #{backup_file} #{cert_file}

    Run `brew doctor` now and after macOS updates, which can restore the roots.
  EOS
rescue OpenSSL::OpenSSLError, SystemCallError => e
  abort "Error: #{e.message}"
end
